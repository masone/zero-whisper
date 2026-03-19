import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var permissions: PermissionsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Status
            HStack {
                Image(systemName: appState.state.systemImage)
                    .foregroundColor(statusColor)
                Text(appState.state.label)
                    .font(.headline)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Divider()

            // Hotkey info
            VStack(alignment: .leading, spacing: 4) {
                Label("Hold Right ⌥ to dictate", systemImage: "mic.fill")
                    .font(.caption)
                Label("Hold Right ⌥ + ⇧ to polish", systemImage: "sparkles")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .foregroundColor(.secondary)

            // Last result
            if !appState.lastOutput.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Last result:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(appState.lastOutput)
                        .font(.caption)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 12)
            }

            // Permissions warnings
            if !permissions.microphoneGranted || !permissions.accessibilityGranted {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    if !permissions.microphoneGranted {
                        Button(action: { permissions.requestMicrophone() }) {
                            Label("Grant Microphone Access", systemImage: "mic.slash")
                                .foregroundColor(.orange)
                        }
                        .buttonStyle(.plain)
                    }
                    if !permissions.accessibilityGranted {
                        Button(action: { permissions.requestAccessibility() }) {
                            Label("Grant Accessibility Access", systemImage: "lock.shield")
                                .foregroundColor(.orange)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .font(.caption)
                .padding(.horizontal, 12)
            }

            Divider()

            // Settings & Quit
            Button("Settings…") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .keyboardShortcut(",")
            .padding(.horizontal, 12)

            Button("Quit LocalVoice") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .frame(width: 260)
    }

    private var statusColor: Color {
        switch appState.state {
        case .idle: return .secondary
        case .recording: return .red
        case .transcribing, .rewriting: return .blue
        case .inserting: return .purple
        case .success: return .green
        case .error: return .orange
        }
    }
}
