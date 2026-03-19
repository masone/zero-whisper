import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var permissions: PermissionsManager

    @State private var helperPath: String = ""

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }
            permissionsTab
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
            debugTab
                .tabItem { Label("Debug", systemImage: "ladybug") }
        }
        .frame(width: 450, height: 320)
        .onAppear {
            helperPath = appState.helperClient.helperScriptPath
            permissions.checkAll()
        }
    }

    private var generalTab: some View {
        Form {
            Section("Hotkeys") {
                Text("Hold Right Option (⌥) → Dictate")
                Text("Hold Right Option (⌥) + Shift (⇧) → Polish")
                Text("Hotkeys are fixed in v1.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Helper") {
                TextField("Helper script path:", text: $helperPath)
                    .onSubmit {
                        appState.helperClient.helperScriptPath = helperPath
                    }
                Text("Python venv: \(appState.helperClient.pythonPath)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private var permissionsTab: some View {
        Form {
            Section("Required Permissions") {
                HStack {
                    Image(systemName: permissions.microphoneGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(permissions.microphoneGranted ? .green : .red)
                    Text("Microphone")
                    Spacer()
                    if !permissions.microphoneGranted {
                        Button("Request") { permissions.requestMicrophone() }
                        Button("Open Settings") { permissions.openMicrophoneSettings() }
                    }
                }

                HStack {
                    Image(systemName: permissions.accessibilityGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(permissions.accessibilityGranted ? .green : .red)
                    Text("Accessibility")
                    Spacer()
                    if !permissions.accessibilityGranted {
                        Button("Request") { permissions.requestAccessibility() }
                        Button("Open Settings") { permissions.openAccessibilitySettings() }
                    }
                }
            }

            Section {
                Button("Re-check Permissions") {
                    permissions.checkAll()
                }
            }

            Section {
                Text("Microphone: needed to record your voice.")
                    .font(.caption)
                Text("Accessibility: needed to paste text into other apps and detect the global hotkey.")
                    .font(.caption)
            }
        }
        .padding()
    }

    private var debugTab: some View {
        Form {
            Section("State") {
                Text("Current: \(appState.state.label)")
            }

            Section("Last Transcript") {
                if appState.lastTranscript.isEmpty {
                    Text("No transcript yet")
                        .foregroundColor(.secondary)
                } else {
                    Text(appState.lastTranscript)
                        .textSelection(.enabled)
                        .frame(maxHeight: 80)
                }
            }

            Section("Last Output") {
                if appState.lastOutput.isEmpty {
                    Text("No output yet")
                        .foregroundColor(.secondary)
                } else {
                    Text(appState.lastOutput)
                        .textSelection(.enabled)
                        .frame(maxHeight: 80)
                }
            }
        }
        .padding()
    }
}
