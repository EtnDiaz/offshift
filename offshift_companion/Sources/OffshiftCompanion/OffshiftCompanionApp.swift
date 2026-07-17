import AppKit
import OffshiftCompanionCore
import SwiftUI

@main
struct OffshiftCompanionApp: App {
    @NSApplicationDelegateAdaptor(OffshiftAppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Offshift Today", id: "dashboard") {
            CompanionDashboardView(store: appDelegate.store)
                .frame(minWidth: 680, minHeight: 560)
        }
        .defaultSize(width: 820, height: 680)
        .commands {
            #if DEBUG
            CommandMenu("Developer") {
                Button("Routine fixture") { appDelegate.store.simulateRoutine() }
                Button("Drift fixture") { appDelegate.store.simulateDrift() }
                Button("Protect fixture") { appDelegate.store.simulateProtect() }
                Button("Gentle night fixture") { appDelegate.store.simulateGentleNightCareNudge() }
                Button("Late-session fixture") { appDelegate.store.simulateLateSessionRisk() }
            }
            #endif
        }

        Window("Offshift protection", id: "protection") {
            ProtectionWindowView(store: appDelegate.store)
                .frame(minWidth: 720, minHeight: 520)
        }
        .defaultSize(width: 1280, height: 800)

        MenuBarExtra("Offshift", systemImage: "moon.stars") {
            MenuBarContent(store: appDelegate.store)
        }

        Settings {
            CompanionSettingsView(store: appDelegate.store)
        }
    }
}

@MainActor
final class OffshiftAppDelegate: NSObject, NSApplicationDelegate {
    let store = CompanionStore()
    private var emergencyExitGate = EmergencyEscapeExitGate()
    private var localKeyMonitor: Any?
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            guard self?.emergencyExitGate.recordEscape(at: Date.now) == true else { return nil }
            NSApp.terminate(nil)
            return nil
        }
        if store.needsOnboarding {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
    }

    private func showOnboarding() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Offshift"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: OnboardingView(store: store) { [weak self] in
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
        })
        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
