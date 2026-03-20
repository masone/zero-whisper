import SwiftUI

@main
struct ZeroWhisperApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var permissions = PermissionsManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState, permissions: permissions)
        } label: {
            Label("ZeroWhisper", systemImage: appState.state.systemImage)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(appState: appState, permissions: permissions)
        }
    }
}
