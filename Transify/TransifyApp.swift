import SwiftUI

@main
struct TransifyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Transify", systemImage: "translate") {
            MenuBarView()
                .environmentObject(appDelegate.settingsStore)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appDelegate.settingsStore)
        }
    }
}
