import AppKit
import SwiftUI

/// SwiftUI owns the intervention content; this narrow AppKit bridge only gives
/// its dedicated window the monitor-covering, black-surface behaviour.
struct InterventionWindowConfigurator: NSViewRepresentable {
    let requiresMonitorCover: Bool
    let shouldKeepPresented: () -> Bool
    let onProtectionWindowReady: () -> Void

    func makeNSView(context: Context) -> InterventionWindowProbe {
        InterventionWindowProbe(
            requiresMonitorCover: requiresMonitorCover,
            shouldKeepPresented: shouldKeepPresented,
            onProtectionWindowReady: onProtectionWindowReady
        )
    }

    func updateNSView(_ nsView: InterventionWindowProbe, context: Context) {
        nsView.requiresMonitorCover = requiresMonitorCover
        nsView.applyInterventionAppearance()
    }
}

final class InterventionWindowProbe: NSView {
    private weak var configuredWindow: NSWindow?
    private var configuredMonitorCover: Bool?
    var requiresMonitorCover: Bool
    private let shouldKeepPresented: () -> Bool
    private let onProtectionWindowReady: () -> Void

    init(
        requiresMonitorCover: Bool,
        shouldKeepPresented: @escaping () -> Bool,
        onProtectionWindowReady: @escaping () -> Void
    ) {
        self.requiresMonitorCover = requiresMonitorCover
        self.shouldKeepPresented = shouldKeepPresented
        self.onProtectionWindowReady = onProtectionWindowReady
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyInterventionAppearance()
    }

    func applyInterventionAppearance() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            // A user action may have paused or disabled Offshift between
            // SwiftUI scheduling this callback and AppKit applying it. Never
            // revive a care screen after that explicit local choice.
            guard self.shouldKeepPresented() else { return }
            guard self.configuredWindow !== window || self.configuredMonitorCover != self.requiresMonitorCover else {
                window.makeKeyAndOrderFront(nil)
                self.onProtectionWindowReady()
                return
            }
            self.configuredWindow = window
            self.configuredMonitorCover = self.requiresMonitorCover
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.remove([.titled, .closable, .miniaturizable, .resizable])
            window.styleMask.insert([.borderless, .fullSizeContentView])
            window.isOpaque = true
            window.backgroundColor = .black
            window.hasShadow = false
            // Care is a reversible intervention, never a system lock. Levels
            // above `.floating` can prevent a SwiftUI window from receiving
            // pointer and keyboard input, which would turn this screen into a
            // trap. Keep the full-screen presentation but use the reliable,
            // interactive AppKit level for every care surface.
            window.level = .floating
            window.ignoresMouseEvents = false
            window.collectionBehavior = self.requiresMonitorCover
                ? [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
                : [.canJoinAllSpaces, .fullScreenAuxiliary]
            if let screen = window.screen ?? NSScreen.main {
                window.setFrame(screen.frame, display: true, animate: false)
            }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            self.onProtectionWindowReady()
        }
    }
}
