import Cocoa
import SwiftUI

/// A small floating pill that appears near the top of the screen during recording/processing.
class RecordingOverlay {
    private var window: NSPanel?

    func show(state: VoiceState) {
        DispatchQueue.main.async { [self] in
            // Kill the old window entirely
            window?.orderOut(nil)
            window = nil

            // Create fresh window with current state
            let pill = NSHostingView(rootView: OverlayPill(state: state))
            pill.frame = NSRect(x: 0, y: 0, width: 300, height: 44)

            let win = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 44),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            win.isOpaque = false
            win.backgroundColor = .clear
            win.hasShadow = false
            win.level = .floating
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            win.contentView = pill
            win.isMovableByWindowBackground = false
            win.ignoresMouseEvents = true

            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let x = screenFrame.midX - 150
                let y = screenFrame.maxY - 60
                win.setFrameOrigin(NSPoint(x: x, y: y))
            }

            win.orderFrontRegardless()
            self.window = win
        }
    }

    func hide() {
        DispatchQueue.main.async { [self] in
            window?.orderOut(nil)
            window = nil
        }
    }
}

private struct OverlayPill: View {
    let state: VoiceState

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 10, height: 10)

            Text(state.label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(pillColor)
        )
        .frame(width: 300, height: 44)
    }

    private var dotColor: Color {
        switch state {
        case .recording: return .red
        case .transcribing, .rewriting: return .yellow
        case .inserting: return .blue
        case .success: return .green
        case .error: return .orange
        case .idle: return .gray
        }
    }

    private var pillColor: Color {
        switch state {
        case .recording: return Color(.sRGB, red: 0.8, green: 0.1, blue: 0.1, opacity: 0.9)
        case .transcribing, .rewriting: return Color(.sRGB, red: 0.2, green: 0.2, blue: 0.6, opacity: 0.9)
        case .success: return Color(.sRGB, red: 0.1, green: 0.5, blue: 0.2, opacity: 0.9)
        case .error: return Color(.sRGB, red: 0.7, green: 0.3, blue: 0.0, opacity: 0.9)
        default: return Color(.sRGB, red: 0.2, green: 0.2, blue: 0.2, opacity: 0.9)
        }
    }
}
