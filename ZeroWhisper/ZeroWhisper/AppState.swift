import Foundation
import SwiftUI

enum Mode: String, Codable {
    case dictate
    case polish
}

enum VoiceState: Equatable {
    case idle
    case recording(mode: Mode)
    case transcribing
    case rewriting
    case inserting
    case success(String)
    case error(String)

    var label: String {
        switch self {
        case .idle: return "Ready"
        case .recording(let mode): return mode == .dictate ? "Recording…" : "Recording (Polish)…"
        case .transcribing: return "Transcribing…"
        case .rewriting: return "Polishing…"
        case .inserting: return "Inserting…"
        case .success(let msg): return msg
        case .error(let msg): return "Error: \(msg)"
        }
    }

    var systemImage: String {
        switch self {
        case .idle: return "mic.fill"
        case .recording: return "mic.badge.plus"
        case .transcribing, .rewriting: return "brain"
        case .inserting: return "doc.on.clipboard"
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    var isBusy: Bool {
        switch self {
        case .idle, .success, .error: return false
        default: return true
        }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var state: VoiceState = .idle
    @Published var lastTranscript: String = ""
    @Published var lastOutput: String = ""

    let audioRecorder = AudioRecorder()
    let helperClient = HelperClient()
    let pasteManager = PasteManager()
    private let hotkeyManager = HotkeyManager()
    private let overlay = RecordingOverlay()

    private var resetTask: Task<Void, Never>?

    init() {
        setupHotkeys()
        helperClient.ensureServerRunning()
    }

    private func setupHotkeys() {
        hotkeyManager.onKeyDown = { [weak self] mode in
            Task { @MainActor [weak self] in
                self?.startRecording(mode: mode)
            }
        }

        hotkeyManager.onKeyUp = { [weak self] in
            Task { @MainActor [weak self] in
                self?.stopRecording()
            }
        }

        hotkeyManager.start()
    }

    func startRecording(mode: Mode) {
        guard !state.isBusy else { return }

        // Cancel any lingering success/error reset and hide old pill
        resetTask?.cancel()
        overlay.hide()

        do {
            try audioRecorder.startRecording()
            state = .recording(mode: mode)
            overlay.show(state: state)
            NSSound.beep()
        } catch {
            handleError("Mic error: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        guard state.isRecording else { return }
        let mode: Mode
        if case .recording(let m) = state {
            mode = m
        } else {
            return
        }

        let wavURL: URL
        do {
            wavURL = try audioRecorder.stopRecording()
        } catch {
            handleError("Save error: \(error.localizedDescription)")
            return
        }

        state = .transcribing
        overlay.show(state: state)

        Task {
            await processAudio(wavURL: wavURL, mode: mode)
        }
    }

    private func processAudio(wavURL: URL, mode: Mode) async {
        defer {
            try? FileManager.default.removeItem(at: wavURL)
        }

        do {
            let result = try await helperClient.transcribe(wavURL: wavURL, mode: mode)

            lastTranscript = result.transcript ?? ""
            lastOutput = result.outputText

            if mode == .polish && state == .transcribing {
                state = .rewriting
                overlay.show(state: state)
            }

            state = .inserting
            overlay.show(state: state)
            pasteManager.paste(result.outputText)

            handleSuccess("Done — text on clipboard")
        } catch {
            // If we have any partial transcript, put it on clipboard
            if !lastTranscript.isEmpty {
                pasteManager.copyToClipboard(lastTranscript)
            }
            handleError(error.localizedDescription)
        }
    }

    private func handleSuccess(_ message: String) {
        state = .success(message)
        overlay.show(state: state)
        scheduleReset()
    }

    func handleError(_ message: String) {
        state = .error(message)
        overlay.show(state: state)
        scheduleReset()
    }

    private func scheduleReset() {
        resetTask?.cancel()
        resetTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if !Task.isCancelled {
                state = .idle
                overlay.hide()
            }
        }
    }
}
