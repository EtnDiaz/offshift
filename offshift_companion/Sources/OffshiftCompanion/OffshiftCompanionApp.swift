import AppKit
import SwiftUI

@main
struct OffshiftCompanionApp: App {
    @NSApplicationDelegateAdaptor(OffshiftAppDelegate.self) private var appDelegate
    @StateObject private var store = CompanionStore()

    var body: some Scene {
        WindowGroup("Offshift", id: "dashboard") {
            CompanionDashboardView(store: store)
                .frame(minWidth: 680, minHeight: 560)
        }
        .defaultSize(width: 820, height: 680)
        .commands {
            #if DEBUG
            CommandMenu("Developer") {
                Button("Routine fixture") { store.simulateRoutine() }
                Button("Drift fixture") { store.simulateDrift() }
                Button("Protect fixture") { store.simulateProtect() }
                Button("Gentle night fixture") { store.simulateGentleNightCareNudge() }
                Button("Late-session fixture") { store.simulateLateSessionRisk() }
            }
            #endif
        }

        WindowGroup("Offshift protection", id: "protection") {
            ProtectionWindowView(store: store)
                .frame(minWidth: 720, minHeight: 520)
        }
        .defaultSize(width: 1280, height: 800)

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
