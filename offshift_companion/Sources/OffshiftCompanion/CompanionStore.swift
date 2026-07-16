import Foundation
import OffshiftCompanionCore

@MainActor
final class CompanionStore: ObservableObject {
    @Published private(set) var assessment = WorkPatternAssessment(
        state: .routine,
        totalActiveDuration: 0,
        currentContinuousActiveDuration: 0,
        appSwitchCount: 0,
        reasons: [.noRecentActivity]
    )
    @Published private(set) var countdownText = "No countdown running"
    @Published private(set) var lockRuleEnabled = false
    @Published private(set) var onCallMessage: String?

    private let shadowLog = InMemoryShadowModeLog()
    private let lockAdapter = NeverLockingTestAdapter()
    private var controller: InterventionController

    init() {
        controller = InterventionController(lockAdapter: lockAdapter, shadowLog: shadowLog)
    }

    var stateLabel: String { assessment.state.rawValue.capitalized }
    var reasons: [String] { assessment.reasons.map(\.rawValue) }
    var canStartCountdown: Bool { assessment.state == .protect && !lockRuleEnabled }

    func simulateRoutine() {
        apply(state: .routine, reasons: [.belowDriftThreshold])
    }

    func simulateDrift() {
        apply(state: .drift, reasons: [.sustainedContinuousActivity])
    }

    func simulateProtect() {
        apply(state: .protect, reasons: [.protectContinuousActivity])
    }

    func startPreLockCountdown() {
        guard controller.startPreLockCountdown(at: .now, duration: 30) else { return }
        countdownText = "30-second local countdown started. Lock rule is disabled, so no lock can occur."
    }

    func cancelPreLockCountdown() {
        guard controller.cancelPreLockCountdown(at: .now) else { return }
        countdownText = "Countdown cancelled."
    }

    func grantOnCallOverride() {
        switch controller.grantOnCallOverride(requestedDuration: 15 * 60, at: .now) {
        case let .granted(override):
            onCallMessage = "On-call override ends at \(override.expiresAt.formatted(date: .omitted, time: .shortened))."
        case let .rejected(reason):
            onCallMessage = reason
        }
    }

    func setLockRuleEnabled(_ enabled: Bool) {
        // This UI is intentionally an explanatory placeholder. A separately reviewed,
        // host-owned local configuration flow must create the actual enabled rule.
        lockRuleEnabled = enabled
        if enabled {
            onCallMessage = "A real lock adapter is not installed in this build; this switch does not lock your Mac."
        }
    }

    private func apply(state: InterventionState, reasons: [AssessmentReason]) {
        assessment = WorkPatternAssessment(
            state: state,
            totalActiveDuration: state == .protect ? 95 * 60 : state == .drift ? 55 * 60 : 20 * 60,
            currentContinuousActiveDuration: state == .protect ? 95 * 60 : state == .drift ? 55 * 60 : 20 * 60,
            appSwitchCount: 0,
            reasons: reasons
        )
        _ = controller.apply(assessment, at: .now)
        countdownText = "No countdown running"
        onCallMessage = nil
    }
}
