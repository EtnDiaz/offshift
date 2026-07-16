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
    private static let cancellationCountDefaultsKey = "localLockScreenRuleCancellationCount"
    private static let consentedSystemVersionDefaultsKey = "localLockScreenRuleConsentedSystemVersion"

    @Published private(set) var isEnabled: Bool
    var onSettingsChanged: (() -> Void)?
    private let defaults: UserDefaults
    private var consentGate: LocalLockConsentGate

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        consentGate = LocalLockConsentGate(
            isEnabled: defaults.bool(forKey: Self.enabledDefaultsKey),
            countdownCancellationCount: defaults.integer(forKey: Self.cancellationCountDefaultsKey)
        )
        if consentGate.isEnabled,
           defaults.string(forKey: Self.consentedSystemVersionDefaultsKey) == Self.currentSystemVersion,
           AXIsProcessTrusted() {
        } else {
            consentGate.disable()
        }
        isEnabled = consentGate.isEnabled
        persistConsentGate()
    }

    var accessibilityStatus: String {
        AXIsProcessTrusted()
            ? "Accessibility permission is available for this local app."
            : "Before a configured rule can lock, grant Offshift Accessibility permission in macOS Privacy & Security."
    }

    @discardableResult
    func enableAfterLocalConfirmation() -> Bool {
        guard AXIsProcessTrusted() else { return false }
        consentGate.enableAfterFreshLocalConsent()
        isEnabled = consentGate.isEnabled
        persistConsentGate()
        defaults.set(Self.currentSystemVersion, forKey: Self.consentedSystemVersionDefaultsKey)
        onSettingsChanged?()
        return true
    }

    func disableImmediately() {
        consentGate.disable()
        isEnabled = consentGate.isEnabled
        persistConsentGate()
        onSettingsChanged?()
    }

    /// Any permission loss invalidates stored consent. Restoring permission later
    /// still needs a fresh Settings confirmation.
    @discardableResult
    func confirmFreshLocalConsentBeforeCountdown() -> Bool {
        guard isEnabled,
              AXIsProcessTrusted(),
              defaults.string(forKey: Self.consentedSystemVersionDefaultsKey) == Self.currentSystemVersion
        else {
            if isEnabled { disableImmediately() }
            return false
        }
        return true
    }

    /// Three rejected countdowns are treated as a local withdrawal of consent.
    @discardableResult
    func recordCountdownCancellation() -> Bool {
        let remainsEnabled = consentGate.recordCountdownCancellation()
        isEnabled = consentGate.isEnabled
        persistConsentGate()
        if !remainsEnabled { onSettingsChanged?() }
        return remainsEnabled
    }

    private static var currentSystemVersion: String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }

    private func persistConsentGate() {
        defaults.set(consentGate.isEnabled, forKey: Self.enabledDefaultsKey)
        defaults.set(consentGate.countdownCancellationCount, forKey: Self.cancellationCountDefaultsKey)
    }
}
