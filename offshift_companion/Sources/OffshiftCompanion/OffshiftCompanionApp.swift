import AppKit
import SwiftUI

@main
struct OffshiftCompanionApp: App {
    @NSApplicationDelegateAdaptor(OffshiftAppDelegate.self) private var appDelegate
    @StateObject private var store = CompanionStore()

    var body: some Scene {
        WindowGroup("Offshift", id: "dashboard") {
            CompanionDashboardView(store: store)
                .frame(minWidth: 520, minHeight: 360)
        }
        .defaultSize(width: 620, height: 460)

        WindowGroup("Offshift protection", id: "protection") {
            ProtectionWindowView(store: store)
                .frame(minWidth: 440, minHeight: 300)
        }
        .defaultSize(width: 480, height: 340)

        MenuBarExtra("Offshift", systemImage: "moon.stars") {
            MenuBarContent(store: store)
        }

        Settings {
            CompanionSettingsView(store: store)
        }
    }
}

final class OffshiftAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
