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
    @Published private(set) var onCallMessage: String?
    @Published private(set) var samplingStatus = "Local aggregate sampling is starting"
    @Published private(set) var windDownStatus = "The wind-down scene is not configured on this Mac."
    @Published private(set) var isRunningWindDown = false

    private let shadowLog = InMemoryShadowModeLog()
    private let disabledLockAdapter = NeverLockingTestAdapter()
    private let systemLockAdapter = SystemLockScreenAdapter()
    private var controller: InterventionController
    private let riskPolicy = WorkPatternRiskPolicy()
    private let sampler = MacActivitySampler()
    private var countdownTimer: Timer?
    private var hasStartedCountdownForProtectEpisode = false
    let homeAssistantSettings = HomeAssistantSettings()
    let lockScreenSettings = LocalLockScreenSettings()

    private let lockCountdownDuration: TimeInterval = 30

    init() {
        controller = InterventionController(lockAdapter: disabledLockAdapter, shadowLog: shadowLog)
        homeAssistantSettings.onSettingsChanged = { [weak self] in
            self?.objectWillChange.send()
        }
        lockScreenSettings.onSettingsChanged = { [weak self] in
            self?.reconfigureLocalLockRule()
        }
        sampler.onIntervalsChanged = { [weak self] intervals in
            self?.applyLiveIntervals(intervals)
        }
        sampler.start()
    }

    var stateLabel: String { assessment.state.rawValue.capitalized }
    var reasons: [String] { assessment.reasons.map(\.rawValue) }
    var lockRuleEnabled: Bool { lockScreenSettings.isEnabled }
    var canStartCountdown: Bool { assessment.state == .protect && lockRuleEnabled && !hasStartedCountdownForProtectEpisode }
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
        guard lockRuleEnabled else {
            countdownText = "The local Lock Screen rule is disabled. Enable it locally in Settings first."
            return
        }
        guard controller.startPreLockCountdown(at: .now, duration: lockCountdownDuration) else { return }
        hasStartedCountdownForProtectEpisode = true
        startCountdownTimer()
        countdownText = "30-second local countdown started. Cancel or use the bounded on-call override before it ends."
    }

    func cancelPreLockCountdown() {
        guard controller.cancelPreLockCountdown(at: .now) else { return }
        hasStartedCountdownForProtectEpisode = true
        stopCountdownTimer()
        countdownText = "Countdown cancelled. The current protect episode will not start another countdown."
    }

    func grantOnCallOverride() {
        switch controller.grantOnCallOverride(requestedDuration: 15 * 60, at: .now) {
        case let .granted(override):
            hasStartedCountdownForProtectEpisode = true
            stopCountdownTimer()
            onCallMessage = "On-call override ends at \(override.expiresAt.formatted(date: .omitted, time: .shortened))."
        case let .rejected(reason):
            onCallMessage = reason
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
        let wasProtect = assessment.state == .protect
        assessment = nextAssessment
        _ = controller.apply(assessment, at: .now)
        if assessment.state != .protect {
            hasStartedCountdownForProtectEpisode = false
            stopCountdownTimer()
            countdownText = "No countdown running"
        } else if !wasProtect {
            hasStartedCountdownForProtectEpisode = false
            maybeStartAutomaticCountdown()
        }
        onCallMessage = nil
    }

    private func reconfigureLocalLockRule() {
        stopCountdownTimer()
        hasStartedCountdownForProtectEpisode = false
        let adapter: any LocalLockAdapter = lockRuleEnabled ? systemLockAdapter : disabledLockAdapter
        controller = InterventionController(
            lockAdapter: adapter,
            shadowLog: shadowLog,
            protectionConfiguration: ProtectionConfiguration(
                localLockScreenRule: LocalLockScreenRule(
                    isEnabled: lockRuleEnabled,
                    countdownDuration: lockCountdownDuration,
                    maximumLockAttemptsPerProtectEpisode: 1
                )
            )
        )
        _ = controller.apply(assessment, at: .now)
        if lockRuleEnabled {
            maybeStartAutomaticCountdown()
        } else {
            countdownText = "Local Lock Screen rule disabled."
        }
        objectWillChange.send()
    }

    private func maybeStartAutomaticCountdown() {
        guard assessment.state == .protect, lockRuleEnabled, !hasStartedCountdownForProtectEpisode else { return }
        startPreLockCountdown()
    }

    private func startCountdownTimer() {
        stopCountdownTimer()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tickCountdown()
            }
        }
    }

    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    private func tickCountdown() {
        switch controller.tick(at: .now) {
        case .waitingForCountdown:
            if case let .countingDown(deadline) = controller.countdown.state {
                let remaining = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
                countdownText = "Local Lock Screen countdown: \(remaining) seconds. Cancel is still available."
            }
        case let .lockRequested(attempt):
            stopCountdownTimer()
            switch attempt {
            case .initiated:
                countdownText = "The locally configured system Lock Screen shortcut was requested."
            case let .notPerformed(reason):
                countdownText = "Lock Screen was not invoked: \(reason)"
            }
        case .suppressedByOverride:
            stopCountdownTimer()
            countdownText = "Countdown suppressed by the active on-call override."
        case .suppressedByDisabledLockRule:
            stopCountdownTimer()
            countdownText = "Countdown suppressed because the local Lock Screen rule is disabled."
        case .suppressedByLockLimit:
            stopCountdownTimer()
            countdownText = "The one-lock limit for this protect episode was reached."
        case .noCountdown:
            stopCountdownTimer()
        }
    }
}
