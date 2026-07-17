import AppKit
import OffshiftCompanionCore
import SwiftUI

@main
struct OffshiftCompanionApp: App {
    @NSApplicationDelegateAdaptor(OffshiftAppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(store: appDelegate.store, showDashboard: appDelegate.showDashboard)
        } label: {
            if let image = OffshiftBrandMark.image {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .accessibilityLabel("Offshift")
            } else {
                Image(systemName: "moon.stars")
            }
        }
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
    private var dashboardWindow: NSWindow?
    private var protectionWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if let image = OffshiftBrandMark.image {
            NSApp.applicationIconImage = image
        }
        store.onProtectionRequested = { [weak self] in
            self?.showProtection()
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            guard self?.emergencyExitGate.recordEscape(at: Date.now) == true else { return nil }
            NSApp.terminate(nil)
            return nil
        }
        if store.needsOnboarding {
            showOnboarding()
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--care-preview") {
            DispatchQueue.main.async { [weak self] in
                self?.store.showDeveloperCarePreview()
            }
        }
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
    }

    func showDashboard() {
        let window = dashboardWindow ?? makeDashboardWindow()
        dashboardWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeDashboardWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Today"
        window.minSize = NSSize(width: 680, height: 560)
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: CompanionDashboardView(store: store))
        return window
    }

    private func showProtection() {
        let window = protectionWindow ?? makeProtectionWindow()
        protectionWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeProtectionWindow() -> NSWindow {
        let frame = (NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1280, height: 800))
        let window = CareScreenWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: ProtectionWindowView(store: store) { [weak self] in
            self?.dismissProtection()
        })
        return window
    }

    private func dismissProtection() {
        store.protectionSurfaceDidDisappear()
        protectionWindow?.orderOut(nil)
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

/// A borderless care surface still needs keyboard focus for its visible
/// controls and the local four-Escape emergency exit. AppKit otherwise
/// refuses to make a bare borderless NSWindow key.
private final class CareScreenWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
