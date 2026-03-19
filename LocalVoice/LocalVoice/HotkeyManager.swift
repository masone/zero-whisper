import Cocoa
import Carbon.HIToolbox

/// Detects Right Option key press/release for push-to-talk.
/// Right Option alone = Dictate mode.
/// Right Option + Shift = Polish mode.
class HotkeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isRightOptionDown = false

    var onKeyDown: ((Mode) -> Void)?
    var onKeyUp: (() -> Void)?

    // Right Option keyCode
    private let kRightOptionKeyCode: UInt16 = 61

    func start() {
        // Global monitor: fires when our app is NOT focused
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }

        // Local monitor: fires when our app IS focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
    }

    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let isOption = event.modifierFlags.contains(.option)
        let isRightKey = event.keyCode == kRightOptionKeyCode

        if isRightKey && isOption && !isRightOptionDown {
            // Right Option pressed
            isRightOptionDown = true
            let mode: Mode = event.modifierFlags.contains(.shift) ? .polish : .dictate
            onKeyDown?(mode)
        } else if !isOption && isRightOptionDown {
            // Option released (either side, but we were tracking right)
            isRightOptionDown = false
            onKeyUp?()
        }
    }

    deinit {
        stop()
    }
}
