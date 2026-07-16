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
    @Published private(set) var samplingStatus = "Local aggregate sampling is starting"
    @Published private(set) var windDownStatus = "The wind-down scene is not configured on this Mac."
    @Published private(set) var isRunningWindDown = false

    private let shadowLog = InMemoryShadowModeLog()
    private let lockAdapter = NeverLockingTestAdapter()
    private var controller: InterventionController
    private let riskPolicy = WorkPatternRiskPolicy()
    private let sampler = MacActivitySampler()
    let homeAssistantSettings = HomeAssistantSettings()

    init() {
        controller = InterventionController(lockAdapter: lockAdapter, shadowLog: shadowLog)
        homeAssistantSettings.onSettingsChanged = { [weak self] in
            self?.objectWillChange.send()
        }
        sampler.onIntervalsChanged = { [weak self] intervals in
            self?.applyLiveIntervals(intervals)
        }
        sampler.start()
    }

    var stateLabel: String { assessment.state.rawValue.capitalized }
    var reasons: [String] { assessment.reasons.map(\.rawValue) }
    var canStartCountdown: Bool { assessment.state == .protect && !lockRuleEnabled }
    var canRunWindDown: Bool { homeAssistantSettings.isConfigured && !isRunningWindDown }

    func simulateRoutine() {
        apply(state: .routine, reasons: [.belowDriftThreshold])
    }

    func simulateDrift() {
        apply(state: .drift, reasons: [.sustainedContinuousActivity])
    }

    func simulateProtect() {
        apply(state: .protect, reasons: [.protectContinuousActivity])
    }

    func simulateLateSessionRisk() {
        let now = Date.now
        let assessment = riskPolicy.assess(
            [
                ActiveAppInterval(
                    startedAt: now.addingTimeInterval(-50 * 60),
                    activeDuration: 50 * 60,
                    appIdentifier: "active-session"
                )
            ],
            context: WorkPatternRiskContext(
                isInsideQuietHours: true,
                snoozeCount: 2,
                hasNextDayEarlyStartConfigured: true
            ),
            at: now
        )
        apply(assessment)
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

    func runWindDownScene() {
        guard let credentials = homeAssistantSettings.credentials() else {
            windDownStatus = "Configure the local Home Assistant endpoint and Keychain token in Settings first."
            return
        }
        isRunningWindDown = true
        windDownStatus = "Sending the locally confirmed wind-down scene…"
        Task { [weak self] in
            let outcome = await HomeAssistantWindDownClient.live.activate(
                configuration: credentials.configuration,
                token: credentials.token
            )
            guard let self else { return }
            isRunningWindDown = false
            windDownStatus = outcome.userMessage
        }
    }

    private func applyLiveIntervals(_ intervals: [ActiveAppInterval]) {
        apply(riskPolicy.assess(intervals, context: .init(), at: .now))
        samplingStatus = "Sampling aggregate active time locally. No content leaves this Mac."
    }

    private func apply(state: InterventionState, reasons: [AssessmentReason]) {
        apply(WorkPatternAssessment(
            state: state,
            totalActiveDuration: state == .protect ? 95 * 60 : state == .drift ? 55 * 60 : 20 * 60,
            currentContinuousActiveDuration: state == .protect ? 95 * 60 : state == .drift ? 55 * 60 : 20 * 60,
            appSwitchCount: 0,
            reasons: reasons
        ))
    }

    private func apply(_ nextAssessment: WorkPatternAssessment) {
        assessment = nextAssessment
        _ = controller.apply(assessment, at: .now)
        countdownText = "No countdown running"
        onCallMessage = nil
    }
}
