import AppKit
import SwiftUI

class SettingsWindowManager {
    static let shared = SettingsWindowManager()
    private var window: NSWindow?

    func open(settingsStore: SettingsStore) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Transify 设置"
        win.contentView = NSHostingView(
            rootView: SettingsView().environmentObject(settingsStore)
        )
        win.center()
        win.isReleasedWhenClosed = false
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = win
    }
}
