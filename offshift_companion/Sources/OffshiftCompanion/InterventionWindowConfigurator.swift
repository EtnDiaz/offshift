import AppKit
import SwiftUI

/// SwiftUI owns the intervention content; this narrow AppKit bridge only gives
/// its dedicated window the monitor-covering, black-surface behaviour.
struct InterventionWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> InterventionWindowProbe {
        InterventionWindowProbe()
    }

    func updateNSView(_ nsView: InterventionWindowProbe, context: Context) {
        nsView.applyInterventionAppearance()
    }
}

final class InterventionWindowProbe: NSView {
    private weak var configuredWindow: NSWindow?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyInterventionAppearance()
    }

    func applyInterventionAppearance() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            guard self.configuredWindow !== window else {
                window.makeKeyAndOrderFront(nil)
                return
            }
            self.configuredWindow = window
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.remove([.titled, .closable, .miniaturizable, .resizable])
            window.styleMask.insert([.borderless, .fullSizeContentView])
            window.isOpaque = true
            window.backgroundColor = .black
            window.hasShadow = false
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            if let screen = window.screen ?? NSScreen.main {
                window.setFrame(screen.frame, display: true, animate: false)
            }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
