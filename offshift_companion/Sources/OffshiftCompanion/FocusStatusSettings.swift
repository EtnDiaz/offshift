import Foundation
import Intents

/// A narrow, optional Focus signal. It reads only the user-authorized boolean
/// Focus status locally; it never exposes a Focus name or sends data elsewhere.
@MainActor
final class FocusStatusSettings: ObservableObject {
    @Published private(set) var authorizationStatus: INFocusStatusAuthorizationStatus
    @Published private(set) var isFocused: Bool?
    var onSettingsChanged: (() -> Void)?
    private var monitorTimer: Timer?

    init() {
        authorizationStatus = INFocusStatusCenter.default.authorizationStatus
        isFocused = nil
        refresh()
    }

    var summary: String {
        switch authorizationStatus {
        case .notDetermined:
            return "Focus Status is off until you allow it."
        case .authorized:
            guard let isFocused else { return "Focus Status is allowed. Refresh to read its current local state." }
            return isFocused ? "A Focus is currently on." : "No Focus is currently on."
        case .denied:
            return "Focus Status was not allowed. You can keep using Offshift without it."
        case .restricted:
            return "Focus Status is restricted on this Mac."
        @unknown default:
            return "Focus Status is unavailable."
        }
    }

    var canRequestAuthorization: Bool {
        authorizationStatus == .notDetermined
    }

    func requestAuthorization() {
        guard canRequestAuthorization else { return }
        INFocusStatusCenter.default.requestAuthorization { [weak self] status in
            Task { @MainActor [weak self] in
                self?.authorizationStatus = status
                self?.refresh()
            }
        }
    }

    func refresh() {
        authorizationStatus = INFocusStatusCenter.default.authorizationStatus
        isFocused = authorizationStatus == .authorized
            ? INFocusStatusCenter.default.focusStatus.isFocused
            : nil
        configureMonitoring()
        onSettingsChanged?()
    }

    private func configureMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        guard authorizationStatus == .authorized else { return }
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }
}
