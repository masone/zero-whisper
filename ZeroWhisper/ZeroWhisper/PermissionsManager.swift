import AVFoundation
import Cocoa

class PermissionsManager: ObservableObject {
    @Published var microphoneGranted = false
    @Published var accessibilityGranted = false

    init() {
        checkAll()
        // Prompt for accessibility on first launch if not granted
        if !accessibilityGranted {
            requestAccessibility()
        }
    }

    func checkAll() {
        checkMicrophone()
        checkAccessibility()
    }

    func checkMicrophone() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            microphoneGranted = true
        case .notDetermined:
            microphoneGranted = false
        case .denied, .restricted:
            microphoneGranted = false
        @unknown default:
            microphoneGranted = false
        }
    }

    func requestMicrophone() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                self?.microphoneGranted = granted
            }
        }
    }

    func checkAccessibility() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    func requestAccessibility() {
        // This opens System Settings with the app pre-selected
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        // Re-check after a short delay (user may need to toggle the switch)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.checkAccessibility()
        }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}
