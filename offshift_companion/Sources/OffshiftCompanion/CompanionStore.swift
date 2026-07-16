import AppKit
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
    @Published private(set) var localControl = LocalInterventionGate()
    @Published private(set) var protectionPresentationToken = 0

    private let shadowLog = InMemoryShadowModeLog()
    private let disabledLockAdapter = NeverLockingTestAdapter()
    private let systemLockAdapter = SystemLockScreenAdapter()
    private var controller: InterventionController
    private let riskPolicy = WorkPatternRiskPolicy()
    private let sampler = MacActivitySampler()
    private let defaults: UserDefaults
    private var countdownTimer: Timer?
    private var overrideExpiryTimer: Timer?
    private var hasStartedCountdownForProtectEpisode = false
    let homeAssistantSettings = HomeAssistantSettings()
    let lockScreenSettings = LocalLockScreenSettings()
    let nightCareSettings = NightCareSettings()

    private let lockCountdownDuration: TimeInterval = 30

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        controller = InterventionController(lockAdapter: disabledLockAdapter, shadowLog: shadowLog)
        localControl = Self.loadLocalControl(from: defaults)
        homeAssistantSettings.onSettingsChanged = { [weak self] in
            self?.objectWillChange.send()
        }
        lockScreenSettings.onSettingsChanged = { [weak self] in
            self?.reconfigureLocalLockRule()
        }
        nightCareSettings.onSettingsChanged = { [weak self] in
            self?.objectWillChange.send()
        }
        sampler.onIntervalsChanged = { [weak self] intervals in
            self?.applyLiveIntervals(intervals)
        }
        if localControl.availability != .disabled {
            sampler.start()
        } else {
            samplingStatus = "Offshift is turned off on this Mac."
        }
    }

    var stateLabel: String { assessment.state.rawValue.capitalized }
    var reasons: [String] { assessment.reasons.map(\.rawValue) }
    var lockRuleEnabled: Bool { lockScreenSettings.isEnabled }
    var canStartCountdown: Bool { isOffshiftEnabled && assessment.state == .protect && lockRuleEnabled && !hasStartedCountdownForProtectEpisode }
    var canRunWindDown: Bool { isOffshiftEnabled && localControl.availability == .active && homeAssistantSettings.isConfigured && !isRunningWindDown }
    var isOffshiftEnabled: Bool { localControl.availability != .disabled }
    var isPaused: Bool {
        if case .paused = localControl.availability { return true }
        return false
    }
    var localControlSummary: String {
        switch localControl.availability {
        case .active:
            return "Offshift is active on this Mac."
        case let .paused(until):
            return "Offshift is paused until \(until.formatted(date: .abbreviated, time: .shortened))."
        case .disabled:
            return "Offshift is turned off on this Mac."
        }
    }

    var pauseActionLabel: String {
        guard nightCareSettings.isEnabled,
              nightCareSettings.schedule.startHour > nightCareSettings.schedule.endHour,
              nightCareSettings.isInsideQuietHours()
        else { return "Pause until tomorrow" }
        return "Pause until \(NightCareSettings.hourLabel(nightCareSettings.schedule.endHour))"
    }

    var careHeadline: String {
        nightCareSettings.isInsideQuietHours()
            ? "The shift can end here"
            : "You have been working for a while"
    }

    var careMessage: String {
        let now = Date.now.formatted(date: .omitted, time: .shortened)
        if nightCareSettings.isInsideQuietHours() {
            return "It’s \(now). Your work stays open, and Offshift will not close Codex or your terminal. The next tokens can wait; caring for yourself does not erase the progress you made tonight."
        }
        return "You have reached your local protection threshold. Your work stays open; choose a short reset, a bounded on-call exception, or pause tonight."
    }

    var careReason: String {
        if nightCareSettings.isInsideQuietHours() {
            let earlyStart = nightCareSettings.hasEarlyStartTomorrow ? " You also marked an early start tomorrow." : ""
            return "Why now: sustained local activity during your \(NightCareSettings.hourLabel(nightCareSettings.startHour))–\(NightCareSettings.hourLabel(nightCareSettings.endHour)) quiet hours.\(earlyStart)"
        }
        return "Why now: sustained local aggregate activity reached your protection threshold."
    }

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

    func takeFive() {
        sampler.resetActivityWindow()
        countdownText = "Take five. Offshift will check local aggregate activity again when you return."
    }

    func startPreLockCountdown() {
        guard localControl.permitsIntervention(at: .now) else {
            countdownText = localControlSummary
            return
        }
        guard lockScreenSettings.confirmFreshLocalConsentBeforeCountdown() else {
            countdownText = "The local Lock Screen rule needs fresh local consent and Accessibility permission in Settings."
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
        if lockScreenSettings.recordCountdownCancellation() {
            countdownText = "Countdown cancelled. The current protect episode will not start another countdown."
        } else {
            countdownText = "Countdown cancelled repeatedly. The local Lock Screen rule was turned off and needs fresh local consent."
        }
    }

    func grantOnCallOverride() {
        guard localControl.permitsIntervention(at: .now) else {
            onCallMessage = localControlSummary
            return
        }
        switch controller.grantOnCallOverride(requestedDuration: 15 * 60, at: .now) {
        case let .granted(override):
            hasStartedCountdownForProtectEpisode = true
            stopCountdownTimer()
            scheduleOverrideExpiry(at: override.expiresAt)
            onCallMessage = "On-call override ends at \(override.expiresAt.formatted(date: .omitted, time: .shortened))."
        case let .rejected(reason):
            onCallMessage = reason
        }
    }

    func pauseUntilTomorrow() {
        let now = Date.now
        let pauseEnd: Date
        if nightCareSettings.isEnabled, nightCareSettings.schedule.startHour > nightCareSettings.schedule.endHour {
            pauseEnd = nightCareSettings.schedule.nextEnd(after: now)
        } else {
            pauseEnd = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))!
        }
        guard localControl.pause(until: pauseEnd, at: now) else { return }
        persistLocalControl()
        suppressLocalInterventions(message: "Offshift is paused until tomorrow. No local countdown, Lock Screen request, or scene can start while paused.")
    }

    func resumeOffshift() {
        localControl.enable()
        persistLocalControl()
        sampler.start()
        samplingStatus = "Local aggregate sampling resumed. No content leaves this Mac."
        objectWillChange.send()
    }

    func disableOffshift() {
        localControl.disable()
        persistLocalControl()
        sampler.stop()
        suppressLocalInterventions(message: "Offshift is turned off on this Mac. Local sampling and interventions stopped.")
    }

    func runWindDownScene() {
        guard localControl.permitsIntervention(at: .now) else {
            windDownStatus = "\(localControlSummary) The wind-down scene was not started."
            return
        }
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
        guard localControl.permitsIntervention(at: .now) else {
            samplingStatus = localControlSummary
            return
        }
        persistLocalControl()
        apply(riskPolicy.assess(
            intervals,
            context: WorkPatternRiskContext(
                isInsideQuietHours: nightCareSettings.isInsideQuietHours(),
                hasNextDayEarlyStartConfigured: nightCareSettings.hasEarlyStartTomorrow
            ),
            at: .now
        ))
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
        guard localControl.permitsIntervention(at: .now) else { return }
        let wasProtect = assessment.state == .protect
        assessment = nextAssessment
        _ = controller.apply(assessment, at: .now)
        if assessment.state != .protect {
            hasStartedCountdownForProtectEpisode = false
            stopCountdownTimer()
            stopOverrideExpiryTimer()
            countdownText = "No countdown running"
        } else if !wasProtect {
            hasStartedCountdownForProtectEpisode = false
            maybeStartAutomaticCountdown()
            protectionPresentationToken &+= 1
            NSApp.activate(ignoringOtherApps: true)
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

    private func suppressLocalInterventions(message: String) {
        _ = controller.apply(
            WorkPatternAssessment(
                state: .routine,
                totalActiveDuration: 0,
                currentContinuousActiveDuration: 0,
                appSwitchCount: 0,
                reasons: [.noRecentActivity]
            ),
            at: .now
        )
        hasStartedCountdownForProtectEpisode = true
        stopCountdownTimer()
        stopOverrideExpiryTimer()
        countdownText = "No countdown running"
        onCallMessage = nil
        samplingStatus = message
        objectWillChange.send()
    }

    private static func loadLocalControl(from defaults: UserDefaults) -> LocalInterventionGate {
        guard defaults.bool(forKey: "offshift.localControl.enabled") else {
            // A missing key means enabled; a recorded false means explicitly disabled.
            if defaults.object(forKey: "offshift.localControl.enabled") != nil {
                return LocalInterventionGate(availability: .disabled)
            }
            return LocalInterventionGate()
        }
        if let pauseUntil = defaults.object(forKey: "offshift.localControl.pauseUntil") as? Date {
            return LocalInterventionGate(availability: .paused(until: pauseUntil))
        }
        return LocalInterventionGate()
    }

    private func persistLocalControl() {
        switch localControl.availability {
        case .active:
            defaults.set(true, forKey: "offshift.localControl.enabled")
            defaults.removeObject(forKey: "offshift.localControl.pauseUntil")
        case let .paused(until):
            defaults.set(true, forKey: "offshift.localControl.enabled")
            defaults.set(until, forKey: "offshift.localControl.pauseUntil")
        case .disabled:
            defaults.set(false, forKey: "offshift.localControl.enabled")
            defaults.removeObject(forKey: "offshift.localControl.pauseUntil")
        }
    }

    private func maybeStartAutomaticCountdown() {
        guard assessment.state == .protect, lockRuleEnabled, !hasStartedCountdownForProtectEpisode else { return }
        guard lockScreenSettings.confirmFreshLocalConsentBeforeCountdown() else {
            countdownText = "The local Lock Screen rule needs fresh local consent and Accessibility permission in Settings."
            return
        }
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

    private func scheduleOverrideExpiry(at deadline: Date) {
        stopOverrideExpiryTimer()
        overrideExpiryTimer = Timer.scheduledTimer(withTimeInterval: max(0.1, deadline.timeIntervalSinceNow), repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleOverrideExpiry()
            }
        }
    }

    private func stopOverrideExpiryTimer() {
        overrideExpiryTimer?.invalidate()
        overrideExpiryTimer = nil
    }

    private func handleOverrideExpiry() {
        _ = controller.tick(at: .now)
        stopOverrideExpiryTimer()
        guard controller.activeOverride == nil,
              assessment.state == .protect,
              localControl.permitsIntervention(at: .now)
        else { return }
        onCallMessage = "Your on-call override ended. Choose what you need next."
        countdownText = "On-call override ended. No new Lock Screen countdown starts automatically."
        protectionPresentationToken &+= 1
        NSApp.activate(ignoringOtherApps: true)
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
