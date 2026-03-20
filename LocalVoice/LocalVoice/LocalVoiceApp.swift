import SwiftUI

@main
struct LocalVoiceApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var permissions = PermissionsManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState, permissions: permissions)
        } label: {
            Label("LocalVoice", systemImage: appState.state.systemImage)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(appState: appState, permissions: permissions)
        }
    }
}
