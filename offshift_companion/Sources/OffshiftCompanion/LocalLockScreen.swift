import ApplicationServices
import Foundation
import OffshiftCompanionCore

/// Uses the standard Control-Command-Q Lock Screen shortcut only after a local rule
/// has been explicitly enabled. This code path is never reachable from MCP or the Worker.
final class SystemLockScreenAdapter: LocalLockAdapter {
    func requestLocalLock(_ request: LockRequest) -> LockAttempt {
        guard AXIsProcessTrusted() else {
            return .notPerformed(reason: "Accessibility permission is required before Offshift can post the system Lock Screen shortcut.")
        }
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 12, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 12, keyDown: false) else {
            return .notPerformed(reason: "macOS could not prepare the system Lock Screen shortcut.")
        }

        keyDown.flags = [.maskCommand, .maskControl]
        keyUp.flags = [.maskCommand, .maskControl]
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return .initiated
    }
}

@MainActor
final class LocalLockScreenSettings: ObservableObject {
    private static let enabledDefaultsKey = "localLockScreenRuleEnabled"

    @Published private(set) var isEnabled: Bool
    var onSettingsChanged: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        isEnabled = defaults.bool(forKey: Self.enabledDefaultsKey)
    }

    var accessibilityStatus: String {
        AXIsProcessTrusted()
            ? "Accessibility permission is available for this local app."
            : "Before a configured rule can lock, grant Offshift Accessibility permission in macOS Privacy & Security."
    }

    func enableAfterLocalConfirmation() {
        UserDefaults.standard.set(true, forKey: Self.enabledDefaultsKey)
        isEnabled = true
        onSettingsChanged?()
    }

    func disableImmediately() {
        UserDefaults.standard.set(false, forKey: Self.enabledDefaultsKey)
        isEnabled = false
        onSettingsChanged?()
    }
}
