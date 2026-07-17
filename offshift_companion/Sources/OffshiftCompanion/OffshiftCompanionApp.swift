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
    private var onboardingWindow: NSWindow?
    private var dashboardWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var protectionWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var statusPopover: NSPopover?
    private var isProtectionPresentationScheduled = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        OffshiftDiagnostics.record("app_launched")
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
        OffshiftDiagnostics.record("app_will_terminate")
        removeEmergencyExitMonitor()
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.isVisible = true
        // Keep a text glyph as the primary mark. It remains visible even when
        // an image asset is unavailable or the system declines an SF Symbol.
        item.button?.title = "☾"
        item.button?.toolTip = "Offshift — open Today and Settings"
        item.button?.target = self
        item.button?.action = #selector(toggleStatusPopover)
        item.button?.sendAction(on: [.leftMouseUp])
        statusItem = item
    }

    @objc private func toggleStatusPopover() {
        guard let button = statusItem?.button else { return }
        let popover = statusPopover ?? makeStatusPopover()
        statusPopover = popover
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        OffshiftDiagnostics.record("tray_popover_opened")
    }

    private func makeStatusPopover() -> NSPopover {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 280, height: 236)
        popover.contentViewController = NSHostingController(rootView: StatusPopoverView(
            store: store,
            openToday: { [weak self] in self?.openTodayFromPopover() },
            openSettings: { [weak self] in self?.openSettingsFromPopover() },
            showDeveloperCare: { [weak self] in self?.showDeveloperCareFromPopover() },
            quit: { NSApplication.shared.terminate(nil) }
        ))
        return popover
    }

    private func openTodayFromPopover() {
        dismissStatusPopover()
        DispatchQueue.main.async { [weak self] in self?.showDashboard() }
    }

    private func openSettingsFromPopover() {
        dismissStatusPopover()
        DispatchQueue.main.async { [weak self] in self?.showSettings() }
    }

    private func showDeveloperCareFromPopover() {
        dismissStatusPopover()
        #if DEBUG
        DispatchQueue.main.async { [weak self] in self?.store.showDeveloperCarePreview() }
        #endif
    }

    private func dismissStatusPopover() {
        statusPopover?.performClose(nil)
    }

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
        // An NSStatusItem `menu` enters an AppKit modal menu-tracking loop.
        // That loop is incompatible with a care surface that can immediately
        // be dismissed and then followed by another tray interaction. The
        // tray therefore uses an NSPopover; close it before showing care and
        // continue on the ordinary main event loop.
        dismissStatusPopover()
        guard !isProtectionPresentationScheduled else { return }
        isProtectionPresentationScheduled = true
        OffshiftDiagnostics.record("care_presentation_scheduled")
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isProtectionPresentationScheduled = false
            self.presentProtectionWindow()
        }
    }

    private func presentProtectionWindow() {
        guard store.shouldKeepProtectionSurfacePresented else { return }
        let window = protectionWindow ?? makeProtectionWindow()
        protectionWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        installEmergencyExitMonitor()
        OffshiftDiagnostics.record("care_surface_presented")
    }

    private func makeProtectionWindow() -> NSWindow {
        let frame = (NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1280, height: 800))
        let window = CareScreenWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.onEscapeKey = { [weak self] in
            self?.recordEmergencyEscape()
        }
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: ProtectionWindowView(store: store) { [weak self] in
            self?.dismissProtection()
        })
        return window
    }

    private func dismissProtection() {
        isProtectionPresentationScheduled = false
        removeEmergencyExitMonitor()
        store.protectionSurfaceDidDisappear()
        protectionWindow?.orderOut(nil)
        OffshiftDiagnostics.record("care_surface_dismissed")
    }

    /// The emergency exit is intentionally local to the care surface. Installing
    /// the monitor only for that surface preserves standard Escape behavior for
    /// menus and normal windows during ordinary use.
    private func installEmergencyExitMonitor() {
        guard localKeyMonitor == nil else { return }

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
    }

    private func recordEmergencyEscape() {
        guard emergencyExitGate.recordEscape(at: Date.now) else { return }
        OffshiftDiagnostics.record("care_emergency_exit")
        NSApp.terminate(nil)
    }

    private func removeEmergencyExitMonitor() {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
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

extension OffshiftAppDelegate: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        OffshiftDiagnostics.record("tray_popover_closed")
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

/// A borderless care surface still needs keyboard focus for its visible
/// controls and the local four-Escape emergency exit. AppKit otherwise
/// refuses to make a bare borderless NSWindow key. `sendEvent` provides the
/// final Escape path without relying on a global event monitor (which macOS
/// may withhold until Input Monitoring is granted).
private final class CareScreenWindow: NSWindow {
    var onEscapeKey: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.keyCode == 53 {
            onEscapeKey?()
            return
        }
        super.sendEvent(event)
    }
}
