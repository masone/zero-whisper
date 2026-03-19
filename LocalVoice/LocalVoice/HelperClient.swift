import Foundation

struct HelperResult {
    let ok: Bool
    let mode: String
    let transcript: String?
    let outputText: String
    let error: String?
}

class HelperClient {
    /// Path to the Python interpreter in the venv.
    /// Defaults to the venv inside the project Helper directory.
    var pythonPath: String = ""
    var helperScriptPath: String = ""

    init() {
        // Try to find paths relative to the app or project
        let projectHelper = findHelperDirectory()
        pythonPath = projectHelper + "/venv/bin/python3"
        helperScriptPath = projectHelper + "/voice_helper.py"
    }

    func transcribe(wavURL: URL, mode: Mode) async throws -> HelperResult {
        let pythonURL = URL(fileURLWithPath: pythonPath)
        let scriptURL = URL(fileURLWithPath: helperScriptPath)

        // Verify files exist
        guard FileManager.default.fileExists(atPath: pythonPath) else {
            // Fallback: try system python3
            return try await runHelper(
                python: "/usr/bin/env",
                args: ["python3", scriptURL.path, "--input", wavURL.path, "--mode", mode.rawValue]
            )
        }

        return try await runHelper(
            python: pythonURL.path,
            args: [scriptURL.path, "--input", wavURL.path, "--mode", mode.rawValue]
        )
    }

    private func runHelper(python: String, args: [String]) async throws -> HelperResult {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: python)
            process.arguments = args

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            // Set environment to avoid Python buffering
            var env = ProcessInfo.processInfo.environment
            env["PYTHONUNBUFFERED"] = "1"
            process.environment = env

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: HelperError.launchFailed(error.localizedDescription))
                return
            }

            // Read output in background
            DispatchQueue.global().async {
                process.waitUntilExit()

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                let stderrStr = String(data: stderrData, encoding: .utf8) ?? ""
                if !stderrStr.isEmpty {
                    print("[Helper stderr] \(stderrStr)")
                }

                guard process.terminationStatus == 0 else {
                    continuation.resume(throwing: HelperError.processExited(
                        code: process.terminationStatus,
                        stderr: stderrStr
                    ))
                    return
                }

                guard !stdoutData.isEmpty else {
                    continuation.resume(throwing: HelperError.emptyOutput)
                    return
                }

                do {
                    let json = try JSONSerialization.jsonObject(with: stdoutData) as? [String: Any]
                    guard let json = json else {
                        continuation.resume(throwing: HelperError.invalidJSON)
                        return
                    }

                    let ok = json["ok"] as? Bool ?? false
                    if !ok {
                        let errorMsg = json["error"] as? String ?? "Unknown helper error"
                        continuation.resume(throwing: HelperError.helperError(errorMsg))
                        return
                    }

                    let result = HelperResult(
                        ok: true,
                        mode: json["mode"] as? String ?? "dictate",
                        transcript: json["transcript"] as? String,
                        outputText: json["output_text"] as? String ?? json["transcript"] as? String ?? "",
                        error: nil
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: HelperError.invalidJSON)
                }
            }
        }
    }

    private func findHelperDirectory() -> String {
        // Look for Helper directory relative to the app bundle or common locations
        let candidates = [
            // Relative to the project (development)
            Bundle.main.bundlePath + "/../../../../Helper",
            // Relative to the executable
            Bundle.main.executablePath.map { URL(fileURLWithPath: $0).deletingLastPathComponent().path + "/../../../../Helper" } ?? "",
            // Hardcoded fallback for dev
            NSHomeDirectory() + "/Projects/mywhisper/Helper",
            "/Volumes/My Shared Files/Projects/mywhisper/Helper"
        ]

        for candidate in candidates {
            let resolved = (candidate as NSString).standardizingPath
            if FileManager.default.fileExists(atPath: resolved + "/voice_helper.py") {
                return resolved
            }
        }

        // Default fallback
        return "/Volumes/My Shared Files/Projects/mywhisper/Helper"
    }

    enum HelperError: LocalizedError {
        case launchFailed(String)
        case processExited(code: Int32, stderr: String)
        case emptyOutput
        case invalidJSON
        case helperError(String)

        var errorDescription: String? {
            switch self {
            case .launchFailed(let msg): return "Failed to launch helper: \(msg)"
            case .processExited(let code, let stderr): return "Helper exited with code \(code): \(stderr)"
            case .emptyOutput: return "Helper produced no output"
            case .invalidJSON: return "Helper returned invalid JSON"
            case .helperError(let msg): return msg
            }
        }
    }
}
