import AppKit
import SwiftUI

/// SwiftUI owns the intervention content; this narrow AppKit bridge only gives
/// its dedicated window the monitor-covering, black-surface behaviour.
struct InterventionWindowConfigurator: NSViewRepresentable {
    let requiresMonitorCover: Bool
    let onProtectionWindowReady: () -> Void

    func makeNSView(context: Context) -> InterventionWindowProbe {
        InterventionWindowProbe(
            requiresMonitorCover: requiresMonitorCover,
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
    private let onProtectionWindowReady: () -> Void

    init(requiresMonitorCover: Bool, onProtectionWindowReady: @escaping () -> Void) {
        self.requiresMonitorCover = requiresMonitorCover
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
            window.level = self.requiresMonitorCover ? .screenSaver : .floating
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
