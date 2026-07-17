import AppKit
import OffshiftCompanionCore
import SwiftUI

@main
struct OffshiftCompanionApp: App {
    @NSApplicationDelegateAdaptor(OffshiftAppDelegate.self) private var appDelegate

    var body: some Scene {
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
    private var globalKeyMonitor: Any?
    private var onboardingWindow: NSWindow?
    private var dashboardWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var protectionWindow: NSWindow?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if let image = OffshiftBrandMark.image {
            NSApp.applicationIconImage = image
        }
        installStatusItem()
        store.onProtectionRequested = { [weak self] in
            self?.showProtection()
        }
        if store.needsOnboarding {
            showOnboarding()
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--settings-preview") {
            DispatchQueue.main.async { [weak self] in
                self?.showSettings()
            }
        }
        if ProcessInfo.processInfo.arguments.contains("--care-preview") {
            DispatchQueue.main.async { [weak self] in
                self?.store.showDeveloperCarePreview()
            }
        }
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        removeEmergencyExitMonitor()
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.isVisible = true
        // Keep a text glyph as the primary mark. It remains visible even when
        // an image asset is unavailable or the system declines an SF Symbol.
        item.button?.title = "☾"
        item.button?.toolTip = "Offshift — open Today and Settings"
        item.menu = makeStatusMenu()
        statusItem = item
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu(title: "Offshift")
        menu.delegate = self
        menu.addItem(withTitle: "Open Today", action: #selector(openToday), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        #if DEBUG
        menu.addItem(.separator())
        menu.addItem(withTitle: "Developer: care screen", action: #selector(showDeveloperCarePreview), keyEquivalent: "")
        #endif
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Offshift", action: #selector(quit), keyEquivalent: "q")
        return menu
    }

    @objc private func openToday() { showDashboard() }

    @objc private func openSettings() {
        showSettings()
    }

    #if DEBUG
    @objc private func showDeveloperCarePreview() {
        store.showDeveloperCarePreview()
    }
    #endif

    @objc private func quit() { NSApp.terminate(nil) }

    func showDashboard() {
        let window = dashboardWindow ?? makeDashboardWindow()
        dashboardWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showSettings() {
        let window = settingsWindow ?? makeSettingsWindow()
        settingsWindow = window
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

    private func makeSettingsWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: CompanionSettingsView(store: store))
        return window
    }

    private func showProtection() {
        guard store.shouldKeepProtectionSurfacePresented else { return }
        let window = protectionWindow ?? makeProtectionWindow()
        protectionWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        installEmergencyExitMonitor()
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
        removeEmergencyExitMonitor()
        store.protectionSurfaceDidDisappear()
        protectionWindow?.orderOut(nil)
    }

    /// The emergency exit is intentionally local to the care surface. Installing
    /// the monitor only for that surface preserves standard Escape behavior for
    /// menus and normal windows during ordinary use.
    private func installEmergencyExitMonitor() {
        guard localKeyMonitor == nil, globalKeyMonitor == nil else { return }

        emergencyExitGate = EmergencyEscapeExitGate()
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  EmergencyEscapeMonitorPolicy.shouldHandle(
                      keyCode: event.keyCode,
                      isProtectionVisible: self.protectionWindow?.isVisible == true
                  )
            else {
                return event
            }

            self.recordEmergencyEscape()
            return nil
        }

        // A screen-saver-level borderless window can be visible without being
        // the AppKit key window. In that case Escape is delivered to the app
        // that previously had focus, so a local monitor alone would make the
        // documented emergency exit unreachable. The global companion monitor
        // observes that complementary path while a care surface is visible.
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return }
            DispatchQueue.main.async {
                guard let self,
                      EmergencyEscapeMonitorPolicy.shouldHandle(
                          keyCode: event.keyCode,
                          isProtectionVisible: self.protectionWindow?.isVisible == true
                      )
                else { return }
                self.recordEmergencyEscape()
            }
        }
    }

    private func recordEmergencyEscape() {
        guard emergencyExitGate.recordEscape(at: Date.now) else { return }
        NSApp.terminate(nil)
    }

    private func removeEmergencyExitMonitor() {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
            self.globalKeyMonitor = nil
        }
        emergencyExitGate = EmergencyEscapeExitGate()
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

/// Restricts the four-Escape exit to a visible local care surface. A monitor
/// must not require `isKeyWindow`: monitor-covering AppKit windows can be
/// intentionally visible while the prior application remains key.
enum EmergencyEscapeMonitorPolicy {
    static func shouldHandle(
        keyCode: UInt16,
        isProtectionVisible: Bool
    ) -> Bool {
        keyCode == 53 && isProtectionVisible
    }
}

extension OffshiftAppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.item(at: 0)?.title = store.isOffshiftEnabled ? "Offshift is on — Open Today" : "Offshift is off — Open Today"
    }
}

/// A borderless care surface still needs keyboard focus for its visible
/// controls and the local four-Escape emergency exit. AppKit otherwise
/// refuses to make a bare borderless NSWindow key.
private final class CareScreenWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
