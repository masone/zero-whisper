import Cocoa
import CoreGraphics

class PasteManager {
    /// Copy text to clipboard and simulate Cmd+V to paste into the frontmost app.
    func paste(_ text: String) {
        copyToClipboard(text)

        // Delay to let clipboard settle and ensure the target app has focus
        // (the overlay panel is non-activating, but give it time just in case)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.simulatePaste()
        }
    }

    /// Copy text to the system clipboard.
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(text, forType: .string)
    }

    /// Simulate Cmd+V keystroke to paste from clipboard.
    private func simulatePaste() {
        // Virtual key code for 'V' is 9
        let vKeyCode: CGKeyCode = 9

        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            print("Failed to create CGEvent for paste")
            return
        }

        // Set Command flag
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        // Post events to the session event tap (reaches frontmost app)
        keyDown.post(tap: .cgSessionEventTap)
        keyUp.post(tap: .cgSessionEventTap)
    }
}
