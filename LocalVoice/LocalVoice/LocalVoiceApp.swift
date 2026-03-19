import SwiftUI

@main
struct LocalVoiceApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var permissions = PermissionsManager()

    private let hotkeyManager = HotkeyManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState, permissions: permissions)
        } label: {
            Label("LocalVoice", systemImage: menuBarIcon)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(appState: appState, permissions: permissions)
        }
    }

    private var menuBarIcon: String {
        appState.state.systemImage
    }

    init() {
        setupHotkeys()
    }

    private func setupHotkeys() {
        hotkeyManager.onKeyDown = { [weak appState] mode in
            guard let appState = appState else { return }
            Task { @MainActor in
                appState.startRecording(mode: mode)
            }
        }

        hotkeyManager.onKeyUp = { [weak appState] in
            guard let appState = appState else { return }
            Task { @MainActor in
                appState.stopRecording()
            }
        }

        hotkeyManager.start()
    }
}
