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
    @Published private(set) var careMode: OffshiftCareMode
    @Published private(set) var isProtectionSurfaceVisible = false
    @Published private(set) var needsOnboarding: Bool

    private let shadowLog = InMemoryShadowModeLog()
    private let disabledLockAdapter = NeverLockingTestAdapter()
    private let systemLockAdapter = SystemLockScreenAdapter()
    private var controller: InterventionController
    private let riskPolicy = WorkPatternRiskPolicy()
    private let sampler = MacActivitySampler()
    private let defaults: UserDefaults
    private var countdownTimer: Timer?
    private var overrideExpiryTimer: Timer?
    private var protectionSurfaceGate = ProtectionSurfaceVisibilityGate()
    private var hasStartedCountdownForProtectEpisode = false
    private var careScreenTriggerSource: CareScreenTriggerSource = .localBehaviour
    private var hasPresentedNightCareDriftPrompt = false
    private let nightCarePresentationPolicy = NightCarePresentationPolicy()
    let homeAssistantSettings = HomeAssistantSettings()
    let lockScreenSettings = LocalLockScreenSettings()
    let nightCareSettings = NightCareSettings()
    let focusStatusSettings = FocusStatusSettings()

    /// A short, always-visible local interval: the intervention wall appears first,
    /// then a separately enabled local rule may request the real system Lock Screen.
    private let lockCountdownDuration: TimeInterval = 10
    private static let careModeDefaultsKey = "offshift.careMode"
    private static let onboardingCompleteDefaultsKey = "offshift.onboardingComplete"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        controller = InterventionController(lockAdapter: disabledLockAdapter, shadowLog: shadowLog)
        let loadedLocalControl = Self.loadLocalControl(from: defaults)
        localControl = loadedLocalControl
        careMode = Self.loadCareMode(from: defaults, localControl: loadedLocalControl)
        needsOnboarding = !defaults.bool(forKey: Self.onboardingCompleteDefaultsKey)
        homeAssistantSettings.onSettingsChanged = { [weak self] in
            self?.objectWillChange.send()
        }
        lockScreenSettings.onSettingsChanged = { [weak self] in
            self?.reconfigureLocalLockRule()
        }
        nightCareSettings.onSettingsChanged = { [weak self] in
            self?.objectWillChange.send()
        }
        focusStatusSettings.onSettingsChanged = { [weak self] in
            self?.objectWillChange.send()
        }
        sampler.onIntervalsChanged = { [weak self] intervals in
            self?.applyLiveIntervals(intervals)
        }
        if needsOnboarding {
            careMode = .off
            localControl.disable()
            persistLocalControl()
            samplingStatus = "Finish the local setup to decide whether Offshift may start sampling."
        } else if careMode == .off {
            localControl.disable()
            persistLocalControl()
            samplingStatus = "Offshift is off. Local sampling and interventions stopped."
        } else if localControl.availability != .disabled {
            sampler.start()
        } else {
            samplingStatus = "Offshift is turned off on this Mac."
        }
    }

    var stateLabel: String { assessment.state.rawValue.capitalized }
    var careModeLabel: String { careMode == .sleep ? "Sleep care" : "Off" }
    var reasons: [String] { assessment.reasons.map(AssessmentReasonCopy.userFacing) }
    var lockRuleEnabled: Bool { lockScreenSettings.isEnabled }
    var isProtectState: Bool { assessment.state == .protect }
    /// The assessment may be a developer fixture, so presentation copy follows
    /// the evaluated context rather than re-reading the wall clock.
    private var careIsDuringQuietHours: Bool {
        assessment.reasons.contains(.insideQuietHours)
    }
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

    var todayHeadline: String {
        guard isOffshiftEnabled else { return "Offshift is off for now" }
        if isPaused { return "Your reminders are paused" }
        switch assessment.state {
        case .routine:
            return "Your next reset is ready when you are"
        case .drift:
            return "A five-minute reset may help"
        case .protect:
            return careIsDuringQuietHours ? "It can end here for tonight" : "Step away from the loop"
        }
    }

    var todayMessage: String {
        guard isOffshiftEnabled else {
            return "Local sampling and care surfaces are stopped on this Mac."
        }
        if isPaused {
            return localControlSummary
        }
        switch assessment.state {
        case .routine:
            return "You can take a reset whenever it helps. Offshift only uses aggregate local timing."
        case .drift:
            return "You have been in a sustained work session. Your work will stay open while you step away."
        case .protect:
            return careMessage
        }
    }

    var todayPrimaryActionTitle: String {
        if !isOffshiftEnabled { return "Turn Offshift on" }
        if isPaused { return "Resume Offshift" }
        return "Start a 5-minute reset"
    }

    var careHeadline: String {
        if isProtectState {
            return careIsDuringQuietHours
                ? "It can end here for tonight"
                : "Step away from the loop"
        }
        return careIsDuringQuietHours ? "A kind time to call it tonight" : "Maybe it is time to pause"
    }

    var careMessage: String {
        let now = Date.now.formatted(date: .omitted, time: .shortened)
        if careIsDuringQuietHours {
            let timeLead = nightCareSettings.isInsideQuietHours() ? "It’s \(now)." : "This is a quiet-hours check-in."
            return "\(timeLead) Your work stays open, and Offshift will not close Codex or your terminal. Your tokens will still be here when you return; caring for yourself does not erase the progress you made tonight."
        }
        return "You have reached your local protection threshold. Your work stays open; choose a short reset, a bounded on-call exception, or pause tonight."
    }

    var careReason: String {
        if careIsDuringQuietHours {
            let earlyStart = nightCareSettings.hasEarlyStartTomorrow ? " You also marked an early start tomorrow." : ""
            return "Why now: sustained local activity during your \(NightCareSettings.hourLabel(nightCareSettings.startHour))–\(NightCareSettings.hourLabel(nightCareSettings.endHour)) quiet hours.\(earlyStart)"
        }
        return "Why now: sustained local aggregate activity reached your protection threshold."
    }

    func simulateRoutine() {
        careScreenTriggerSource = .localBehaviour
        apply(state: .routine, reasons: [.belowDriftThreshold])
    }

    func simulateDrift() {
        careScreenTriggerSource = .localBehaviour
        apply(state: .drift, reasons: [.sustainedContinuousActivity])
    }

    func simulateProtect() {
        showDeveloperCarePreview()
    }

    /// A Debug-only local visual test route. It deliberately cannot start the
    /// optional Lock Screen countdown or a smart-home action.
    func showDeveloperCarePreview() {
        careScreenTriggerSource = .developerPreview
        apply(state: .protect, reasons: [.protectContinuousActivity])
    }

    func simulateLateSessionRisk() {
        careScreenTriggerSource = .localBehaviour
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

    func simulateGentleNightCareNudge() {
        careScreenTriggerSource = .localBehaviour
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

    func pauseNoticesForFifteenMinutes() {
        let now = Date.now
        let until = now.addingTimeInterval(15 * 60)
        guard localControl.pause(until: until, at: now) else { return }
        persistLocalControl()
        suppressLocalInterventions(message: "Offshift notices are paused until \(until.formatted(date: .omitted, time: .shortened)).")
    }

    /// Called only by the local borderless protection window after it has become
    /// key. See ADR 0016: this is intentionally not reachable from any remote
    /// integration or model-controlled path.
    func protectionSurfaceDidBecomeVisible() {
        guard assessment.state == .protect, localControl.permitsIntervention(at: .now) else { return }
        protectionSurfaceGate.markSurfaceVisible()
        isProtectionSurfaceVisible = protectionSurfaceGate.isVisible
        maybeStartAutomaticCountdown()
    }

    /// Closing or hiding the local care surface must fail closed: a countdown
    /// cannot outlive the thing that explained it and exposed its cancel route.
    func protectionSurfaceDidDisappear() {
        protectionSurfaceGate.endProtectEpisode()
        isProtectionSurfaceVisible = protectionSurfaceGate.isVisible
        guard controller.cancelPreLockCountdown(at: .now) else { return }
        hasStartedCountdownForProtectEpisode = true
        stopCountdownTimer()
        countdownText = "Care screen closed. The local countdown was cancelled."
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
        countdownText = "10-second local countdown started. Cancel or use the bounded on-call override before it ends."
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

    @discardableResult
    func grantOnCallOverride() -> Bool {
        guard localControl.permitsIntervention(at: .now) else {
            onCallMessage = localControlSummary
            return false
        }
        switch controller.grantOnCallOverride(requestedDuration: 15 * 60, at: .now) {
        case let .granted(override):
            hasStartedCountdownForProtectEpisode = true
            stopCountdownTimer()
            scheduleOverrideExpiry(at: override.expiresAt)
            onCallMessage = "On-call override ends at \(override.expiresAt.formatted(date: .omitted, time: .shortened))."
            return true
        case let .rejected(reason):
            onCallMessage = reason
            return false
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

    func setCareMode(_ mode: OffshiftCareMode) {
        careMode = mode
        defaults.set(mode.rawValue, forKey: Self.careModeDefaultsKey)
        switch mode {
        case .sleep:
            nightCareSettings.setEnabled(true)
            localControl.enable()
            persistLocalControl()
            sampler.start()
            samplingStatus = "Sleep care is active. Local aggregate sampling resumed. No content leaves this Mac."
            objectWillChange.send()
        case .off:
            nightCareSettings.setEnabled(false)
            stopOffshiftForCareMode()
        }
    }

    /// Reserved for a separately entitled native adapter. The local user-facing
    /// selector shares this exact reducer, so an `off` transition always wins.
    func applyScreenTimeMode(_ mode: OffshiftCareMode) {
        setCareMode(mode)
    }

    func resumeOffshift() {
        setCareMode(.sleep)
    }

    func completeOnboarding(enableLocalCare: Bool) {
        defaults.set(true, forKey: Self.onboardingCompleteDefaultsKey)
        needsOnboarding = false
        setCareMode(enableLocalCare ? .sleep : .off)
    }

    func disableOffshift() {
        setCareMode(.off)
    }

    private func stopOffshiftForCareMode() {
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
        careScreenTriggerSource = .localBehaviour
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
        let previousAssessment = assessment
        let wasProtect = previousAssessment.state == .protect
        let careContext = WorkPatternRiskContext(
            isInsideQuietHours: nightCareSettings.isInsideQuietHours(),
            hasNextDayEarlyStartConfigured: nightCareSettings.hasEarlyStartTomorrow
        )
        let shouldPresentCare = nightCarePresentationPolicy.shouldPresentCare(
            previous: previousAssessment,
            next: nextAssessment,
            context: careContext,
            hasPresentedForCurrentDriftEpisode: hasPresentedNightCareDriftPrompt
        )
        assessment = nextAssessment
        _ = controller.apply(assessment, at: .now)
        if assessment.state != .protect {
            hasStartedCountdownForProtectEpisode = false
            protectionSurfaceGate.endProtectEpisode()
            isProtectionSurfaceVisible = protectionSurfaceGate.isVisible
            stopCountdownTimer()
            stopOverrideExpiryTimer()
            countdownText = "No countdown running"
        }
        if assessment.state == .routine {
            hasPresentedNightCareDriftPrompt = false
        }
        if assessment.state == .drift && shouldPresentCare {
            hasPresentedNightCareDriftPrompt = true
        }
        if shouldPresentCare {
            if assessment.state == .protect && !wasProtect {
                hasStartedCountdownForProtectEpisode = false
                protectionSurfaceGate.beginProtectEpisode()
                isProtectionSurfaceVisible = protectionSurfaceGate.isVisible
            }
            protectionPresentationToken &+= 1
            NSApp.activate(ignoringOtherApps: true)
        } else if assessment.state == .protect && !wasProtect {
            hasStartedCountdownForProtectEpisode = false
            protectionSurfaceGate.beginProtectEpisode()
            isProtectionSurfaceVisible = protectionSurfaceGate.isVisible
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
        if !lockRuleEnabled {
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
        protectionSurfaceGate.endProtectEpisode()
        isProtectionSurfaceVisible = protectionSurfaceGate.isVisible
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

    private static func loadCareMode(from defaults: UserDefaults, localControl: LocalInterventionGate) -> OffshiftCareMode {
        if let rawValue = defaults.string(forKey: careModeDefaultsKey),
           let mode = OffshiftCareMode(rawValue: rawValue) {
            return mode
        }
        if case .disabled = localControl.availability { return .off }
        return .sleep
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
        if !careScreenTriggerSource.permitsAutomaticLockCountdown {
            countdownText = "Developer preview only. The local Lock Screen rule will not start."
            return
        }
        guard assessment.state == .protect,
              protectionSurfaceGate.isVisible,
              lockRuleEnabled,
              !hasStartedCountdownForProtectEpisode
        else { return }
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

private enum AssessmentReasonCopy {
    static func userFacing(_ reason: AssessmentReason) -> String {
        switch reason {
        case .noRecentActivity:
            return "No sustained local activity yet"
        case .belowDriftThreshold:
            return "You are below your reminder threshold"
        case .sustainedContinuousActivity:
            return "You have been active without a meaningful break"
        case .sustainedActivityWithFrequentSwitching:
            return "You have been active with frequent app switching"
        case .protectContinuousActivity:
            return "You have been active long enough for a stronger check-in"
        case .protectActivityWithFrequentSwitching:
            return "Long activity and frequent app switching reached your protection threshold"
        case .insideQuietHours:
            return "It is inside your configured quiet hours"
        case .repeatedSnoozes:
            return "You deferred recent reminders"
        case .nextDayEarlyStartConfigured:
            return "You marked an early start tomorrow"
        }
    }
}
