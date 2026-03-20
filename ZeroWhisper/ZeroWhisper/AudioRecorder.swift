import AVFoundation
import Foundation

class AudioRecorder {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var tempFileURL: URL?

    private let targetSampleRate: Double = 16000
    private let targetChannels: AVAudioChannelCount = 1

    func startRecording() throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0 else {
            throw RecorderError.noMicrophone
        }

        // Use /tmp so the Python helper server can access the file
        let tempDir = URL(fileURLWithPath: "/tmp")
        let fileName = "zerowhisper_\(Int(Date().timeIntervalSince1970)).wav"
        let fileURL = tempDir.appendingPathComponent(fileName)

        // Use float32 for the converter output (AVAudioConverter works best with float)
        guard let converterFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: targetChannels,
            interleaved: false
        ) else {
            throw RecorderError.formatError
        }

        // Write as 16-bit PCM WAV (standard format, compatible with Python wave module)
        let wavSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: targetSampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        let file = try AVAudioFile(forWriting: fileURL, settings: wavSettings)

        // Create converter from input format to target format
        guard let converter = AVAudioConverter(from: inputFormat, to: converterFormat) else {
            throw RecorderError.formatError
        }

        // Install tap on input node using the input's native format
        let bufferSize: AVAudioFrameCount = 4096
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { buffer, _ in

            // Calculate output buffer size based on sample rate ratio
            let ratio = converterFormat.sampleRate / inputFormat.sampleRate
            let outputFrameCount = max(AVAudioFrameCount(Double(buffer.frameLength) * ratio), 1)
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: converterFormat, frameCapacity: outputFrameCount) else { return }

            var error: NSError?
            let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            if status == .haveData, outputBuffer.frameLength > 0 {
                do {
                    // AVAudioFile handles float32→int16 conversion on write
                    try file.write(from: outputBuffer)
                } catch {
                    print("Write error: \(error)")
                }
            }
        }

        try engine.start()

        self.audioEngine = engine
        self.audioFile = file
        self.tempFileURL = fileURL
    }

    func stopRecording() throws -> URL {
        guard let engine = audioEngine, let fileURL = tempFileURL else {
            throw RecorderError.notRecording
        }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        self.audioEngine = nil
        self.audioFile = nil

        // Verify file exists and has content
        let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let size = attrs[.size] as? UInt64 ?? 0
        if size < 100 {
            throw RecorderError.emptyRecording
        }

        return fileURL
    }

    enum RecorderError: LocalizedError {
        case noMicrophone
        case formatError
        case notRecording
        case emptyRecording

        var errorDescription: String? {
            switch self {
            case .noMicrophone: return "No microphone available"
            case .formatError: return "Audio format error"
            case .notRecording: return "Not currently recording"
            case .emptyRecording: return "Recording was empty"
            }
        }
    }
}
