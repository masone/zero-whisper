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

    private var resetTask: Task<Void, Never>?

    func startRecording(mode: Mode) {
        guard !state.isBusy else { return }

        do {
            try audioRecorder.startRecording()
            state = .recording(mode: mode)
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

        Task {
            await processAudio(wavURL: wavURL, mode: mode)
        }
    }

    private func processAudio(wavURL: URL, mode: Mode) async {
        do {
            let result = try await helperClient.transcribe(wavURL: wavURL, mode: mode)

            lastTranscript = result.transcript ?? ""
            lastOutput = result.outputText

            if mode == .polish && state == .transcribing {
                state = .rewriting
                // Helper already did the rewriting, so we just move on
            }

            state = .inserting
            pasteManager.paste(result.outputText)

            handleSuccess("Done")

            // Clean up temp file
            try? FileManager.default.removeItem(at: wavURL)
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
        scheduleReset()
    }

    func handleError(_ message: String) {
        state = .error(message)
        scheduleReset()
    }

    private func scheduleReset() {
        resetTask?.cancel()
        resetTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if !Task.isCancelled {
                state = .idle
            }
        }
    }
}
