import Foundation

/// The only smart-home capability in the MVP. This identifier never comes from a
/// ChatGPT tool, a Worker response, or freeform model text.
public enum WindDownScene {
    public static let id = "wind-down"
    public static let homeAssistantEntityId = "scene.offshift_wind_down"
    public static let servicePath = "api/services/scene/turn_on"
}

public enum HomeAssistantConfigurationError: Error, Equatable, Sendable {
    case invalidBaseURL
    case missingToken
}

/// A locally configured Home Assistant base URL. It is never included in MCP data.
public struct HomeAssistantWindDownConfiguration: Equatable, Sendable {
    public let baseURL: URL

    public init(baseURL: URL) throws {
        guard let scheme = baseURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              baseURL.host != nil,
              baseURL.user == nil,
              baseURL.password == nil,
              baseURL.query == nil,
              baseURL.fragment == nil else {
            throw HomeAssistantConfigurationError.invalidBaseURL
        }
        self.baseURL = baseURL
    }

    public func makeActivationRequest(token: String) throws -> URLRequest {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else { throw HomeAssistantConfigurationError.missingToken }

        let endpoint = baseURL
            .appendingPathComponent(WindDownScene.servicePath)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(trimmedToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["entity_id": WindDownScene.homeAssistantEntityId])
        return request
    }
}

public enum WindDownSceneOutcome: Equatable, Sendable {
    case activated
    case unauthorized
    case sceneNotFound
    case rejected(statusCode: Int)
    case unavailable

    public var userMessage: String {
        switch self {
        case .activated:
            return "The local wind-down scene ran."
        case .unauthorized:
            return "Home Assistant rejected the stored token. Update it locally in Settings."
        case .sceneNotFound:
            return "Home Assistant could not find scene.offshift_wind_down. Create that scene locally, then retry."
        case let .rejected(statusCode):
            return "Home Assistant rejected the wind-down request (HTTP \(statusCode)). Nothing else was changed."
        case .unavailable:
            return "Home Assistant is unavailable. Nothing was retried automatically; you can retry after checking your local connection."
        }
    }
}

public enum WindDownSceneResponseMapper {
    public static func map(statusCode: Int) -> WindDownSceneOutcome {
        switch statusCode {
        case 200, 201:
            return .activated
        case 401, 403:
            return .unauthorized
        case 404:
            return .sceneNotFound
        default:
            return .rejected(statusCode: statusCode)
        }
    }
}

public enum WindDownSceneTransportResult: Equatable, Sendable {
    case response(statusCode: Int)
    case unavailable
}

/// The executor is injectable so tests can prove that failed calls are not retried.
/// Only the live companion supplies the URLSession transport.
public struct HomeAssistantWindDownClient: Sendable {
    private let execute: @Sendable (URLRequest) async -> WindDownSceneTransportResult

    public init(execute: @escaping @Sendable (URLRequest) async -> WindDownSceneTransportResult) {
        self.execute = execute
    }

    public func activate(
        configuration: HomeAssistantWindDownConfiguration,
        token: String
    ) async -> WindDownSceneOutcome {
        guard let request = try? configuration.makeActivationRequest(token: token) else {
            return .unavailable
        }
        switch await execute(request) {
        case let .response(statusCode):
            return WindDownSceneResponseMapper.map(statusCode: statusCode)
        case .unavailable:
            return .unavailable
        }
    }

    public static let live = HomeAssistantWindDownClient { request in
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return .unavailable }
            return .response(statusCode: httpResponse.statusCode)
        } catch {
            return .unavailable
        }
    }
}

/// Aggregate active-application timing. `appIdentifier` should be an opaque stable identifier;
/// it is never interpreted as source-code or screen-content data.
public struct ActiveAppInterval: Equatable, Sendable {
    public let startedAt: Date
    public let activeDuration: TimeInterval
    public let appIdentifier: String

    public init(startedAt: Date, activeDuration: TimeInterval, appIdentifier: String) {
        self.startedAt = startedAt
        self.activeDuration = activeDuration
        self.appIdentifier = appIdentifier
    }
}

/// Converts a local sample period into a coarse active interval. Callers provide only
/// elapsed durations; no event payload, application title, code, or screen content is accepted.
public enum AggregateActivityIntervalFactory {
    public static func make(
        endingAt now: Date,
        sampleDuration: TimeInterval,
        idleDuration: TimeInterval,
        opaqueCategory: String = "active-session"
    ) -> ActiveAppInterval? {
        guard sampleDuration > 0 else { return nil }
        let activeDuration = max(0, sampleDuration - max(0, idleDuration))
        guard activeDuration > 0 else { return nil }
        return ActiveAppInterval(
            startedAt: now.addingTimeInterval(-activeDuration),
            activeDuration: activeDuration,
            appIdentifier: opaqueCategory
        )
    }
}

public enum InterventionState: String, Codable, CaseIterable, Sendable {
    case routine
    case drift
    case protect
}

/// A local-only escape hatch for every intervention. Its state is intentionally
/// not serializable into MCP data and may never be changed by a model or Worker.
public enum LocalInterventionAvailability: Equatable, Sendable {
    case active
    case paused(until: Date)
    case disabled
}

/// Holds the local user's immediate pause/off decision. A host is responsible
/// for persisting it locally; this policy is deliberately deterministic so it
/// can be tested independently from UI and UserDefaults.
public struct LocalInterventionGate: Equatable, Sendable {
    public private(set) var availability: LocalInterventionAvailability

    public init(availability: LocalInterventionAvailability = .active) {
        self.availability = availability
    }

    @discardableResult
    public mutating func pause(until date: Date, at now: Date) -> Bool {
        guard date > now else { return false }
        availability = .paused(until: date)
        return true
    }

    public mutating func disable() {
        availability = .disabled
    }

    public mutating func enable() {
        availability = .active
    }

    /// Returns whether a new local intervention may begin. An elapsed pause
    /// clears itself only when the companion next evaluates local state.
    public mutating func permitsIntervention(at now: Date) -> Bool {
        if case let .paused(until) = availability, now >= until {
            availability = .active
        }
        return availability == .active
    }
}

public enum AssessmentReason: String, Codable, CaseIterable, Sendable {
    case noRecentActivity
    case belowDriftThreshold
    case sustainedContinuousActivity
    case sustainedActivityWithFrequentSwitching
    case protectContinuousActivity
    case protectActivityWithFrequentSwitching
    case insideQuietHours
    case repeatedSnoozes
    case nextDayEarlyStartConfigured
}

public struct WorkPatternAssessment: Equatable, Sendable {
    public let state: InterventionState
    public let totalActiveDuration: TimeInterval
    public let currentContinuousActiveDuration: TimeInterval
    public let appSwitchCount: Int
    /// Ordered threshold facts explaining why this state was selected.
    public let reasons: [AssessmentReason]

    public init(
        state: InterventionState,
        totalActiveDuration: TimeInterval,
        currentContinuousActiveDuration: TimeInterval,
        appSwitchCount: Int,
        reasons: [AssessmentReason]
    ) {
        self.state = state
        self.totalActiveDuration = totalActiveDuration
        self.currentContinuousActiveDuration = currentContinuousActiveDuration
        self.appSwitchCount = appSwitchCount
        self.reasons = reasons
    }
}

public struct WorkPatternHeuristicConfiguration: Equatable, Sendable {
    public var observationWindow: TimeInterval
    public var breakGap: TimeInterval
    public var driftContinuousActivity: TimeInterval
    public var protectContinuousActivity: TimeInterval
    public var driftTotalActivity: TimeInterval
    public var protectTotalActivity: TimeInterval
    public var driftAppSwitches: Int
    public var protectAppSwitches: Int

    public init(
        observationWindow: TimeInterval = 2 * 60 * 60,
        breakGap: TimeInterval = 5 * 60,
        driftContinuousActivity: TimeInterval = 45 * 60,
        protectContinuousActivity: TimeInterval = 90 * 60,
        driftTotalActivity: TimeInterval = 45 * 60,
        protectTotalActivity: TimeInterval = 75 * 60,
        driftAppSwitches: Int = 6,
        protectAppSwitches: Int = 12
    ) {
        self.observationWindow = observationWindow
        self.breakGap = breakGap
        self.driftContinuousActivity = driftContinuousActivity
        self.protectContinuousActivity = protectContinuousActivity
        self.driftTotalActivity = driftTotalActivity
        self.protectTotalActivity = protectTotalActivity
        self.driftAppSwitches = driftAppSwitches
        self.protectAppSwitches = protectAppSwitches
    }
}

/// A user-owned local schedule. It is a time-of-day explanation only; callers
/// must still require sustained local activity before escalating an action.
public struct QuietHoursSchedule: Equatable, Sendable {
    public let startHour: Int
    public let endHour: Int

    public init(startHour: Int = 23, endHour: Int = 7) {
        precondition((0..<24).contains(startHour))
        precondition((0..<24).contains(endHour))
        precondition(startHour != endHour)
        self.startHour = startHour
        self.endHour = endHour
    }

    public func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return contains(hour: hour)
    }

    public func contains(hour: Int) -> Bool {
        guard (0..<24).contains(hour) else { return false }
        if startHour < endHour { return hour >= startHour && hour < endHour }
        return hour >= startHour || hour < endHour
    }

    /// Returns the end of the quiet window containing `date` when possible.
    /// For an overnight schedule, this avoids a "pause until tomorrow" that
    /// expires one minute after the user accepts it at 23:59.
    public func nextEnd(after date: Date, calendar: Calendar = .current) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let todayEnd = calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: startOfDay) ?? date
        if startHour > endHour, date >= todayEnd {
            return calendar.date(byAdding: .day, value: 1, to: todayEnd) ?? todayEnd
        }
        if startHour < endHour, date >= todayEnd {
            return calendar.date(byAdding: .day, value: 1, to: todayEnd) ?? todayEnd
        }
        return todayEnd
    }
}

/// A transparent rule set over aggregate timing. It does not infer health, fatigue, or intent.
public struct WorkPatternHeuristic: Sendable {
    public let configuration: WorkPatternHeuristicConfiguration

    public init(configuration: WorkPatternHeuristicConfiguration = .init()) {
        precondition(configuration.observationWindow > 0)
        precondition(configuration.breakGap >= 0)
        precondition(configuration.driftContinuousActivity > 0)
        precondition(configuration.protectContinuousActivity >= configuration.driftContinuousActivity)
        precondition(configuration.driftTotalActivity > 0)
        precondition(configuration.protectTotalActivity >= configuration.driftTotalActivity)
        precondition(configuration.driftAppSwitches >= 0)
        precondition(configuration.protectAppSwitches >= configuration.driftAppSwitches)
        self.configuration = configuration
    }

    public func assess(_ intervals: [ActiveAppInterval], at now: Date) -> WorkPatternAssessment {
        let lowerBound = now.addingTimeInterval(-configuration.observationWindow)
        let clipped = intervals.compactMap { interval -> ClippedInterval? in
            guard interval.activeDuration > 0 else { return nil }
            let originalEnd = interval.startedAt.addingTimeInterval(interval.activeDuration)
            let start = max(interval.startedAt, lowerBound)
            let end = min(originalEnd, now)
            guard end > start else { return nil }
            return ClippedInterval(start: start, end: end, appIdentifier: interval.appIdentifier)
        }
        .sorted { lhs, rhs in
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            if lhs.end != rhs.end { return lhs.end < rhs.end }
            return lhs.appIdentifier < rhs.appIdentifier
        }

        guard !clipped.isEmpty else {
            return WorkPatternAssessment(
                state: .routine,
                totalActiveDuration: 0,
                currentContinuousActiveDuration: 0,
                appSwitchCount: 0,
                reasons: [.noRecentActivity]
            )
        }

        let merged = mergeActivityRanges(from: clipped)
        let totalActive = merged.reduce(0) { $0 + $1.duration }
        let continuousActive = activeDurationSinceMostRecentBreak(in: merged)
        let appSwitches = countAppSwitches(in: clipped)

        let protectsForContinuity = continuousActive >= configuration.protectContinuousActivity
        let protectsForSwitching = totalActive >= configuration.protectTotalActivity
            && appSwitches >= configuration.protectAppSwitches
        if protectsForContinuity || protectsForSwitching {
            var reasons: [AssessmentReason] = []
            if protectsForContinuity { reasons.append(.protectContinuousActivity) }
            if protectsForSwitching { reasons.append(.protectActivityWithFrequentSwitching) }
            return WorkPatternAssessment(
                state: .protect,
                totalActiveDuration: totalActive,
                currentContinuousActiveDuration: continuousActive,
                appSwitchCount: appSwitches,
                reasons: reasons
            )
        }

        let driftsForContinuity = continuousActive >= configuration.driftContinuousActivity
        let driftsForSwitching = totalActive >= configuration.driftTotalActivity
            && appSwitches >= configuration.driftAppSwitches
        if driftsForContinuity || driftsForSwitching {
            var reasons: [AssessmentReason] = []
            if driftsForContinuity { reasons.append(.sustainedContinuousActivity) }
            if driftsForSwitching { reasons.append(.sustainedActivityWithFrequentSwitching) }
            return WorkPatternAssessment(
                state: .drift,
                totalActiveDuration: totalActive,
                currentContinuousActiveDuration: continuousActive,
                appSwitchCount: appSwitches,
                reasons: reasons
            )
        }

        return WorkPatternAssessment(
            state: .routine,
            totalActiveDuration: totalActive,
            currentContinuousActiveDuration: continuousActive,
            appSwitchCount: appSwitches,
            reasons: [.belowDriftThreshold]
        )
    }

    private func mergeActivityRanges(from intervals: [ClippedInterval]) -> [ActivityRange] {
        var ranges: [ActivityRange] = []
        for interval in intervals {
            guard var latest = ranges.popLast() else {
                ranges.append(ActivityRange(start: interval.start, end: interval.end))
                continue
            }
            if interval.start <= latest.end {
                latest.end = max(latest.end, interval.end)
                ranges.append(latest)
            } else {
                ranges.append(latest)
                ranges.append(ActivityRange(start: interval.start, end: interval.end))
            }
        }
        return ranges
    }

    private func activeDurationSinceMostRecentBreak(in ranges: [ActivityRange]) -> TimeInterval {
        var activeDuration: TimeInterval = 0
        var previousEnd: Date?
        for range in ranges {
            if let previousEnd, range.start.timeIntervalSince(previousEnd) >= configuration.breakGap {
                activeDuration = 0
            }
            activeDuration += range.duration
            previousEnd = range.end
        }
        return activeDuration
    }

    private func countAppSwitches(in intervals: [ClippedInterval]) -> Int {
        var previousApp: String?
        var switches = 0
        for interval in intervals {
            if let previousApp, previousApp != interval.appIdentifier {
                switches += 1
            }
            previousApp = interval.appIdentifier
        }
        return switches
    }
}

/// Extra context a user can choose to include in a work-pattern explanation.
/// It intentionally contains only coarse, non-content facts. Calendar access, Screen Time,
/// camera frames, and biometric inferences are not represented here.
public struct WorkPatternRiskContext: Equatable, Sendable {
    public var isInsideQuietHours: Bool
    public var snoozeCount: Int
    public var hasNextDayEarlyStartConfigured: Bool

    public init(
        isInsideQuietHours: Bool = false,
        snoozeCount: Int = 0,
        hasNextDayEarlyStartConfigured: Bool = false
    ) {
        self.isInsideQuietHours = isInsideQuietHours
        self.snoozeCount = max(0, snoozeCount)
        self.hasNextDayEarlyStartConfigured = hasNextDayEarlyStartConfigured
    }
}

/// Combines aggregate activity with opted-in context while preserving explainability.
/// Context alone never creates an intervention: active time is always required.
public struct WorkPatternRiskPolicy: Sendable {
    public let activityHeuristic: WorkPatternHeuristic
    public let snoozesRequiredForProtectEscalation: Int

    public init(
        activityHeuristic: WorkPatternHeuristic = .init(),
        snoozesRequiredForProtectEscalation: Int = 2
    ) {
        precondition(snoozesRequiredForProtectEscalation > 0)
        self.activityHeuristic = activityHeuristic
        self.snoozesRequiredForProtectEscalation = snoozesRequiredForProtectEscalation
    }

    public func assess(
        _ intervals: [ActiveAppInterval],
        context: WorkPatternRiskContext,
        at now: Date
    ) -> WorkPatternAssessment {
        let activity = activityHeuristic.assess(intervals, at: now)
        guard activity.state != .routine else { return activity }

        var reasons = activity.reasons
        if context.isInsideQuietHours {
            reasons.append(.insideQuietHours)
        }
        if context.snoozeCount >= snoozesRequiredForProtectEscalation {
            reasons.append(.repeatedSnoozes)
        }
        if context.hasNextDayEarlyStartConfigured {
            reasons.append(.nextDayEarlyStartConfigured)
        }

        let escalatesToProtect = activity.state == .drift
            && context.isInsideQuietHours
            && context.snoozeCount >= snoozesRequiredForProtectEscalation
        return WorkPatternAssessment(
            state: escalatesToProtect ? .protect : activity.state,
            totalActiveDuration: activity.totalActiveDuration,
            currentContinuousActiveDuration: activity.currentContinuousActiveDuration,
            appSwitchCount: activity.appSwitchCount,
            reasons: reasons
        )
    }
}

private struct ClippedInterval {
    let start: Date
    let end: Date
    let appIdentifier: String
}

private struct ActivityRange {
    let start: Date
    var end: Date

    var duration: TimeInterval { end.timeIntervalSince(start) }
}

public enum CountdownState: Equatable, Sendable {
    case idle
    case countingDown(deadline: Date)
    case cancelled
    case fired
}

public enum CountdownTickResult: Equatable, Sendable {
    case waiting(remaining: TimeInterval)
    case fired
    case inactive
}

/// A clock-driven countdown. A host may call `tick(at:)` from any timer; cancellation is immediate.
public struct PreLockCountdown: Equatable, Sendable {
    public private(set) var state: CountdownState = .idle

    public init() {}

    public mutating func start(at now: Date, duration: TimeInterval) -> CountdownState {
        precondition(duration > 0)
        state = .countingDown(deadline: now.addingTimeInterval(duration))
        return state
    }

    public mutating func cancel() -> Bool {
        guard case .countingDown = state else { return false }
        state = .cancelled
        return true
    }

    public mutating func tick(at now: Date) -> CountdownTickResult {
        guard case let .countingDown(deadline) = state else { return .inactive }
        guard now >= deadline else { return .waiting(remaining: deadline.timeIntervalSince(now)) }
        state = .fired
        return .fired
    }
}

public struct OnCallOverridePolicy: Equatable, Sendable {
    public let maximumDuration: TimeInterval
    public let maximumGrantsPerProtectEpisode: Int

    public init(maximumDuration: TimeInterval = 15 * 60, maximumGrantsPerProtectEpisode: Int = 1) {
        precondition(maximumDuration > 0)
        precondition(maximumGrantsPerProtectEpisode >= 0)
        self.maximumDuration = maximumDuration
        self.maximumGrantsPerProtectEpisode = maximumGrantsPerProtectEpisode
    }
}

public struct OnCallOverride: Equatable, Sendable {
    public let grantedAt: Date
    public let expiresAt: Date
    public let grantedDuration: TimeInterval

    public func isActive(at now: Date) -> Bool { now < expiresAt }
}

/// A local-only freshness gate for a high-impact system-lock rule. Hosts own
/// persistence and platform permission checks; this value keeps the decision
/// bounded and unit-testable without exposing it to MCP data.
public struct LocalLockConsentGate: Equatable, Sendable {
    public let maximumCountdownCancellations: Int
    public private(set) var isEnabled: Bool
    public private(set) var countdownCancellationCount: Int

    public init(
        isEnabled: Bool = false,
        countdownCancellationCount: Int = 0,
        maximumCountdownCancellations: Int = 3
    ) {
        precondition(maximumCountdownCancellations > 0)
        self.maximumCountdownCancellations = maximumCountdownCancellations
        self.isEnabled = isEnabled
        self.countdownCancellationCount = max(0, countdownCancellationCount)
    }

    public mutating func enableAfterFreshLocalConsent() {
        isEnabled = true
        countdownCancellationCount = 0
    }

    public mutating func disable() {
        isEnabled = false
        countdownCancellationCount = 0
    }

    /// Returns whether the rule remains enabled after this cancellation.
    @discardableResult
    public mutating func recordCountdownCancellation() -> Bool {
        guard isEnabled else { return false }
        countdownCancellationCount += 1
        if countdownCancellationCount >= maximumCountdownCancellations {
            disable()
            return false
        }
        return true
    }
}

public struct LockRequest: Equatable, Sendable {
    public let requestedAt: Date
    public let reason: String

    public init(requestedAt: Date, reason: String) {
        self.requestedAt = requestedAt
        self.reason = reason
    }
}

public enum LockAttempt: Equatable, Sendable {
    case initiated
    case notPerformed(reason: String)
}

/// An explicitly local, opt-in rule for invoking the lock adapter. Disabled by default.
/// A host must configure this rule locally; model output must not enable it.
public struct LocalLockScreenRule: Equatable, Sendable {
    public let isEnabled: Bool
    public let countdownDuration: TimeInterval
    public let maximumLockAttemptsPerProtectEpisode: Int

    public init(
        isEnabled: Bool = false,
        countdownDuration: TimeInterval = 30,
        maximumLockAttemptsPerProtectEpisode: Int = 1
    ) {
        precondition(countdownDuration > 0)
        precondition(maximumLockAttemptsPerProtectEpisode > 0)
        self.isEnabled = isEnabled
        self.countdownDuration = countdownDuration
        self.maximumLockAttemptsPerProtectEpisode = maximumLockAttemptsPerProtectEpisode
    }
}

/// Safety configuration for protect-state actions. No screen-lock adapter is contacted by default.
public struct ProtectionConfiguration: Equatable, Sendable {
    public let localLockScreenRule: LocalLockScreenRule

    public init(localLockScreenRule: LocalLockScreenRule = .init()) {
        self.localLockScreenRule = localLockScreenRule
    }
}

/// The only boundary where a user-approved host may attach a system Lock Screen integration.
/// The core never calls the operating system directly.
public protocol LocalLockAdapter: AnyObject {
    func requestLocalLock(_ request: LockRequest) -> LockAttempt
}

/// Safe default for development and tests. It records requests and never locks the screen.
public final class NeverLockingTestAdapter: LocalLockAdapter {
    public private(set) var requests: [LockRequest] = []

    public init() {}

    public func requestLocalLock(_ request: LockRequest) -> LockAttempt {
        requests.append(request)
        return .notPerformed(reason: "No real lock adapter is installed.")
    }
}

public enum ShadowModeAction: String, Codable, Sendable {
    case assessment
    case stateTransition
    case countdownStarted
    case countdownCancelled
    case overrideGranted
    case overrideRejected
    case overrideExpired
    case lockRequested
    case lockSuppressed
}

public struct ShadowModeEvent: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let action: ShadowModeAction
    public let detail: String

    public init(timestamp: Date, action: ShadowModeAction, detail: String) {
        self.timestamp = timestamp
        self.action = action
        self.detail = detail
    }
}

public protocol ShadowModeLogging: AnyObject {
    func append(_ event: ShadowModeEvent)
}

public final class InMemoryShadowModeLog: ShadowModeLogging {
    public private(set) var events: [ShadowModeEvent] = []

    public init() {}

    public func append(_ event: ShadowModeEvent) {
        events.append(event)
    }
}

/// Appends JSON-lines to a caller-selected local file. It has no network behaviour.
public final class LocalShadowModeLog: ShadowModeLogging {
    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    public func append(_ event: ShadowModeEvent) {
        guard let data = try? encoder.encode(event) else { return }
        let line = data + Data([0x0A])
        let directory = fileURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: fileURL.path) {
            guard let handle = try? FileHandle(forWritingTo: fileURL) else { return }
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
        } else {
            try? line.write(to: fileURL, options: .atomic)
        }
    }
}

public enum OverrideGrantResult: Equatable, Sendable {
    case granted(OnCallOverride)
    case rejected(reason: String)
}

public enum InterventionTickResult: Equatable, Sendable {
    case waitingForCountdown
    case noCountdown
    case suppressedByOverride
    case suppressedByDisabledLockRule
    case suppressedByLockLimit
    case lockRequested(LockAttempt)
}

/// Stateful coordinator for explainable, user-cancellable interventions.
public final class InterventionController {
    public private(set) var state: InterventionState = .routine
    public private(set) var countdown = PreLockCountdown()
    public private(set) var activeOverride: OnCallOverride?

    private let lockAdapter: any LocalLockAdapter
    private let shadowLog: any ShadowModeLogging
    private let overridePolicy: OnCallOverridePolicy
    private let protectionConfiguration: ProtectionConfiguration
    private var grantsInProtectEpisode = 0
    private var lockAttemptsInProtectEpisode = 0

    public init(
        lockAdapter: any LocalLockAdapter = NeverLockingTestAdapter(),
        shadowLog: any ShadowModeLogging = InMemoryShadowModeLog(),
        overridePolicy: OnCallOverridePolicy = .init(),
        protectionConfiguration: ProtectionConfiguration = .init()
    ) {
        self.lockAdapter = lockAdapter
        self.shadowLog = shadowLog
        self.overridePolicy = overridePolicy
        self.protectionConfiguration = protectionConfiguration
    }

    @discardableResult
    public func apply(_ assessment: WorkPatternAssessment, at now: Date) -> InterventionState {
        expireOverrideIfNeeded(at: now)
        let previous = state
        state = assessment.state
        shadowLog.append(ShadowModeEvent(
            timestamp: now,
            action: .assessment,
            detail: "state=\(assessment.state.rawValue); activeSeconds=\(Int(assessment.totalActiveDuration)); continuousSeconds=\(Int(assessment.currentContinuousActiveDuration)); appSwitches=\(assessment.appSwitchCount); reasons=\(assessment.reasons.map(\.rawValue).joined(separator: ","))"
        ))

        if previous != state {
            shadowLog.append(ShadowModeEvent(
                timestamp: now,
                action: .stateTransition,
                detail: "\(previous.rawValue)->\(state.rawValue)"
            ))
        }

        if state != .protect {
            if countdown.cancel() {
                shadowLog.append(ShadowModeEvent(timestamp: now, action: .countdownCancelled, detail: "assessment returned to \(state.rawValue)"))
            }
            activeOverride = nil
            grantsInProtectEpisode = 0
            lockAttemptsInProtectEpisode = 0
        } else if previous != .protect {
            grantsInProtectEpisode = 0
            lockAttemptsInProtectEpisode = 0
        }
        return state
    }

    @discardableResult
    public func startPreLockCountdown(at now: Date, duration: TimeInterval) -> Bool {
        guard state == .protect else { return false }
        expireOverrideIfNeeded(at: now)
        guard activeOverride == nil else { return false }
        _ = countdown.start(at: now, duration: duration)
        shadowLog.append(ShadowModeEvent(timestamp: now, action: .countdownStarted, detail: "durationSeconds=\(Int(duration))"))
        return true
    }

    @discardableResult
    public func cancelPreLockCountdown(at now: Date) -> Bool {
        guard countdown.cancel() else { return false }
        shadowLog.append(ShadowModeEvent(timestamp: now, action: .countdownCancelled, detail: "cancelled by caller"))
        return true
    }

    public func grantOnCallOverride(requestedDuration: TimeInterval, at now: Date) -> OverrideGrantResult {
        expireOverrideIfNeeded(at: now)
        guard state == .protect else {
            return rejectOverride("Override is available only while the state is protect.", at: now)
        }
        guard requestedDuration > 0 else {
            return rejectOverride("Requested duration must be positive.", at: now)
        }
        guard grantsInProtectEpisode < overridePolicy.maximumGrantsPerProtectEpisode else {
            return rejectOverride("Override grant limit reached for this protect episode.", at: now)
        }

        let grantedDuration = min(requestedDuration, overridePolicy.maximumDuration)
        let override = OnCallOverride(
            grantedAt: now,
            expiresAt: now.addingTimeInterval(grantedDuration),
            grantedDuration: grantedDuration
        )
        activeOverride = override
        grantsInProtectEpisode += 1
        _ = countdown.cancel()
        shadowLog.append(ShadowModeEvent(
            timestamp: now,
            action: .overrideGranted,
            detail: "grantedSeconds=\(Int(grantedDuration)); expiresAt=\(override.expiresAt.timeIntervalSince1970)"
        ))
        return .granted(override)
    }

    public func tick(at now: Date) -> InterventionTickResult {
        expireOverrideIfNeeded(at: now)
        switch countdown.tick(at: now) {
        case .waiting:
            return .waitingForCountdown
        case .inactive:
            return .noCountdown
        case .fired:
            guard state == .protect else { return .noCountdown }
            if let activeOverride, activeOverride.isActive(at: now) {
                shadowLog.append(ShadowModeEvent(timestamp: now, action: .lockSuppressed, detail: "on-call override active"))
                return .suppressedByOverride
            }
            guard protectionConfiguration.localLockScreenRule.isEnabled else {
                shadowLog.append(ShadowModeEvent(
                    timestamp: now,
                    action: .lockSuppressed,
                    detail: "local lock-screen rule is disabled"
                ))
                return .suppressedByDisabledLockRule
            }
            guard lockAttemptsInProtectEpisode < protectionConfiguration.localLockScreenRule.maximumLockAttemptsPerProtectEpisode else {
                shadowLog.append(ShadowModeEvent(
                    timestamp: now,
                    action: .lockSuppressed,
                    detail: "local lock-screen rule reached its protect-episode attempt limit"
                ))
                return .suppressedByLockLimit
            }
            let request = LockRequest(requestedAt: now, reason: "Pre-lock countdown elapsed while protect state remained active.")
            lockAttemptsInProtectEpisode += 1
            let attempt = lockAdapter.requestLocalLock(request)
            shadowLog.append(ShadowModeEvent(timestamp: now, action: .lockRequested, detail: "\(attempt)"))
            return .lockRequested(attempt)
        }
    }

    private func expireOverrideIfNeeded(at now: Date) {
        guard let activeOverride, !activeOverride.isActive(at: now) else { return }
        self.activeOverride = nil
        shadowLog.append(ShadowModeEvent(timestamp: now, action: .overrideExpired, detail: "on-call override expired"))
    }

    private func rejectOverride(_ detail: String, at now: Date) -> OverrideGrantResult {
        shadowLog.append(ShadowModeEvent(timestamp: now, action: .overrideRejected, detail: detail))
        return .rejected(reason: detail)
    }
}
