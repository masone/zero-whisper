import Cocoa
import SwiftUI

/// A small floating pill that appears near the top of the screen during recording/processing.
class RecordingOverlay {
    private var window: NSWindow?
    private var hostingView: NSHostingView<AnyView>?

    func show(state: VoiceState) {
        if window == nil {
            createWindow()
        }

        hostingView?.rootView = AnyView(OverlayPill(state: state))

        // Auto-size window to fit content
        if let hosting = hostingView {
            let fittingSize = hosting.fittingSize
            let width = min(max(fittingSize.width, 120), 500)
            let height = min(max(fittingSize.height, 36), 100)
            window?.setContentSize(NSSize(width: width, height: height))
            hosting.frame = NSRect(origin: .zero, size: NSSize(width: width, height: height))

            // Re-center horizontally
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let x = screenFrame.midX - width / 2
                let y = screenFrame.maxY - 60
                window?.setFrameOrigin(NSPoint(x: x, y: y))
            }
        }

        window?.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func createWindow() {
        let pill = OverlayPill(state: .idle)
        let hosting = NSHostingView(rootView: AnyView(pill))
        hosting.frame = NSRect(x: 0, y: 0, width: 250, height: 44)

        let win = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 250, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.level = .floating
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.contentView = hosting
        win.isMovableByWindowBackground = true

        // Position: top center of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 125
            let y = screenFrame.maxY - 60
            win.setFrameOrigin(NSPoint(x: x, y: y))
        }

        self.window = win
        self.hostingView = hosting
    }
}

private struct OverlayPill: View {
    let state: VoiceState

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .fill(dotColor.opacity(0.5))
                        .frame(width: 18, height: 18)
                        .opacity(state.isRecording ? 1 : 0)
                )

            Text(state.label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(pillColor)
        )
        .animation(.easeInOut(duration: 0.2), value: state)
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
