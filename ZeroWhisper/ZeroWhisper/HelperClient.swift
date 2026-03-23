import Foundation

struct HelperResult {
    let ok: Bool
    let mode: String
    let transcript: String?
    let outputText: String
    let error: String?
}

class HelperClient {
    private let serverPort = 8426
    private let serverURL: URL
    private var serverProcess: Process?

    private var pythonPath: String = ""
    private var serverScriptPath: String = ""

    init() {
        serverURL = URL(string: "http://127.0.0.1:\(serverPort)")!
        let projectHelper = findHelperDirectory()
        pythonPath = projectHelper + "/venv/bin/python3"
        serverScriptPath = projectHelper + "/server.py"
    }

    /// Start the helper server and wait until it's ready.
    func ensureServerRunning() {
        Task.detached { [self] in
            if await self.isServerHealthy() {
                print("[HelperClient] Server already running")
                return
            }
            self.launchServer()
            // Wait for server to become ready (up to 60s for model loading)
            for i in 0..<120 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                if await self.isServerHealthy() {
                    print("[HelperClient] Server is ready")
                    return
                }
                if i == 10 {
                    print("[HelperClient] Still waiting for model to load...")
                }
            }
            print("[HelperClient] Server failed to start in time")
        }
    }

    func transcribe(wavURL: URL, mode: Mode) async throws -> HelperResult {
        // If server isn't up, try to start it and wait
        if !(await isServerHealthy()) {
            launchServer()
            // Wait up to 60s
            var ready = false
            for _ in 0..<120 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                if await isServerHealthy() {
                    ready = true
                    break
                }
            }
            if !ready {
                throw HelperError.serverNotRunning
            }
        }

        return try await httpTranscribe(wavURL: wavURL, mode: mode)
    }

    // MARK: - HTTP

    private func isServerHealthy() async -> Bool {
        let url = serverURL.appendingPathComponent("health")
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            return json?["ok"] as? Bool == true
        } catch {
            return false
        }
    }

    private func httpTranscribe(wavURL: URL, mode: Mode) async throws -> HelperResult {
        let url = serverURL.appendingPathComponent("transcribe")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let body: [String: String] = [
            "input": wavURL.path,
            "mode": mode.rawValue,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HelperError.httpError("No HTTP response")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HelperError.invalidJSON
        }

        let ok = json["ok"] as? Bool ?? false
        if !ok {
            let errorMsg = json["error"] as? String ?? "Unknown helper error"
            throw HelperError.helperError(errorMsg)
        }

        return HelperResult(
            ok: true,
            mode: json["mode"] as? String ?? "dictate",
            transcript: json["transcript"] as? String,
            outputText: json["output_text"] as? String ?? json["transcript"] as? String ?? "",
            error: nil
        )
    }

    // MARK: - Server lifecycle

    private func launchServer() {
        // Don't launch again if we already have a running process
        if let existing = serverProcess, existing.isRunning { return }

        guard FileManager.default.fileExists(atPath: pythonPath) else {
            print("[HelperClient] Python venv not found at \(pythonPath). Run setup.sh first.")
            return
        }

        guard FileManager.default.fileExists(atPath: serverScriptPath) else {
            print("[HelperClient] server.py not found at \(serverScriptPath)")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [serverScriptPath]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle(forWritingAtPath: "/dev/stderr") ?? FileHandle.nullDevice

        var env = ProcessInfo.processInfo.environment
        env["PYTHONUNBUFFERED"] = "1"
        process.environment = env

        do {
            try process.run()
            serverProcess = process
            print("[HelperClient] Launched helper server (PID \(process.processIdentifier))")
        } catch {
            print("[HelperClient] Failed to launch server: \(error)")
        }
    }

    func stopServer() {
        serverProcess?.terminate()
        serverProcess = nil
    }

    // MARK: - Paths

    private func findHelperDirectory() -> String {
        // Helper is bundled inside the .app at Contents/Resources/Helper
        if let resourcePath = Bundle.main.resourcePath {
            let bundled = resourcePath + "/Helper"
            if FileManager.default.fileExists(atPath: bundled + "/server.py") {
                return bundled
            }
        }
        // Fallback: adjacent to the project (development)
        let devPath = (Bundle.main.bundlePath + "/../../../../Helper" as NSString).standardizingPath
        return devPath
    }

    enum HelperError: LocalizedError {
        case serverNotRunning
        case invalidJSON
        case helperError(String)
        case httpError(String)

        var errorDescription: String? {
            switch self {
            case .serverNotRunning: return "Helper server not running. Check that setup.sh was run."
            case .invalidJSON: return "Helper returned invalid JSON"
            case .helperError(let msg): return msg
            case .httpError(let msg): return "HTTP error: \(msg)"
            }
        }
    }
}
