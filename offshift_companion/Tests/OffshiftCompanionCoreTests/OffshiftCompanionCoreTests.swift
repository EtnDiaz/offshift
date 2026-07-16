import XCTest
@testable import OffshiftCompanionCore

final class WorkPatternHeuristicTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testNoRecentActivityIsRoutineWithExplicitReason() {
        let assessment = WorkPatternHeuristic().assess([], at: now)

        XCTAssertEqual(assessment.state, .routine)
        XCTAssertEqual(assessment.reasons, [.noRecentActivity])
    }

    func testAggregateSampleFactoryNeverRetainsApplicationContent() {
        let interval = AggregateActivityIntervalFactory.make(
            endingAt: now,
            sampleDuration: 60,
            idleDuration: 15
        )

        XCTAssertEqual(interval?.activeDuration, 45)
        XCTAssertEqual(interval?.startedAt, now.addingTimeInterval(-45))
        XCTAssertEqual(interval?.appIdentifier, "active-session")
        XCTAssertNil(AggregateActivityIntervalFactory.make(endingAt: now, sampleDuration: 60, idleDuration: 60))
    }

    func testContinuousActivityMovesThroughDriftToProtectDeterministically() {
        let heuristic = WorkPatternHeuristic()
        let drift = heuristic.assess([
            ActiveAppInterval(startedAt: now.addingTimeInterval(-50 * 60), activeDuration: 50 * 60, appIdentifier: "app.a")
        ], at: now)
        let protect = heuristic.assess([
            ActiveAppInterval(startedAt: now.addingTimeInterval(-95 * 60), activeDuration: 95 * 60, appIdentifier: "app.a")
        ], at: now)

        XCTAssertEqual(drift.state, .drift)
        XCTAssertEqual(drift.reasons, [.sustainedContinuousActivity])
        XCTAssertEqual(protect.state, .protect)
        XCTAssertEqual(protect.reasons, [.protectContinuousActivity])
    }

    func testContextExplainsLateSessionAndRepeatedSnoozesCanEscalateDrift() {
        let assessment = WorkPatternRiskPolicy().assess(
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

        XCTAssertEqual(assessment.state, .protect)
        XCTAssertEqual(
            assessment.reasons,
            [
                .sustainedContinuousActivity,
                .insideQuietHours,
                .repeatedSnoozes,
                .nextDayEarlyStartConfigured
            ]
        )
    }

    func testContextCannotEscalateWithoutRecentActivity() {
        let assessment = WorkPatternRiskPolicy().assess(
            [],
            context: WorkPatternRiskContext(
                isInsideQuietHours: true,
                snoozeCount: 99,
                hasNextDayEarlyStartConfigured: true
            ),
            at: now
        )

        XCTAssertEqual(assessment.state, .routine)
        XCTAssertEqual(assessment.reasons, [.noRecentActivity])
    }

    func testSubstantialBreakResetsContinuousActivity() {
        let heuristic = WorkPatternHeuristic()
        let assessment = heuristic.assess([
            ActiveAppInterval(startedAt: now.addingTimeInterval(-70 * 60), activeDuration: 30 * 60, appIdentifier: "app.a"),
            ActiveAppInterval(startedAt: now.addingTimeInterval(-30 * 60), activeDuration: 30 * 60, appIdentifier: "app.a")
        ], at: now)

        XCTAssertEqual(assessment.currentContinuousActiveDuration, 30 * 60)
        XCTAssertEqual(assessment.state, .routine)
        XCTAssertEqual(assessment.reasons, [.belowDriftThreshold])
    }

    func testIntervalsOutsideWindowAreIgnored() {
        let assessment = WorkPatternHeuristic().assess([
            ActiveAppInterval(startedAt: now.addingTimeInterval(-4 * 60 * 60), activeDuration: 90 * 60, appIdentifier: "app.a")
        ], at: now)

        XCTAssertEqual(assessment.state, .routine)
        XCTAssertEqual(assessment.reasons, [.noRecentActivity])
    }
}

final class LocalInterventionGateTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testPauseSuppressesInterventionsUntilItsLocalExpiry() {
        var gate = LocalInterventionGate()
        let until = now.addingTimeInterval(60)

        XCTAssertTrue(gate.pause(until: until, at: now))
        XCTAssertFalse(gate.permitsIntervention(at: now.addingTimeInterval(59)))
        XCTAssertTrue(gate.permitsIntervention(at: until))
        XCTAssertEqual(gate.availability, .active)
    }

    func testDisableRequiresAnExplicitLocalEnable() {
        var gate = LocalInterventionGate()
        gate.disable()

        XCTAssertFalse(gate.permitsIntervention(at: now.addingTimeInterval(24 * 60 * 60)))
        gate.enable()
        XCTAssertTrue(gate.permitsIntervention(at: now))
    }

    func testPauseRejectsAPastDeadline() {
        var gate = LocalInterventionGate()
        XCTAssertFalse(gate.pause(until: now, at: now))
        XCTAssertEqual(gate.availability, .active)
    }
}

final class QuietHoursScheduleTests: XCTestCase {
    func testOvernightQuietHoursIncludeMidnightAndExcludeTheEndHour() {
        let schedule = QuietHoursSchedule(startHour: 23, endHour: 7)

        XCTAssertFalse(schedule.contains(hour: 22))
        XCTAssertTrue(schedule.contains(hour: 23))
        XCTAssertTrue(schedule.contains(hour: 0))
        XCTAssertTrue(schedule.contains(hour: 6))
        XCTAssertFalse(schedule.contains(hour: 7))
    }

    func testSameDayQuietHoursRespectBothBoundaries() {
        let schedule = QuietHoursSchedule(startHour: 13, endHour: 17)

        XCTAssertFalse(schedule.contains(hour: 12))
        XCTAssertTrue(schedule.contains(hour: 13))
        XCTAssertTrue(schedule.contains(hour: 16))
        XCTAssertFalse(schedule.contains(hour: 17))
    }

    func testOvernightQuietHoursEndOnTheFollowingMorningAtLateEvening() {
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: DateComponents(year: 2026, month: 7, day: 17, hour: 23, minute: 59))!
        let end = QuietHoursSchedule(startHour: 23, endHour: 7).nextEnd(after: date, calendar: calendar)

        XCTAssertEqual(calendar.component(.day, from: end), 18)
        XCTAssertEqual(calendar.component(.hour, from: end), 7)
    }
}

final class LocalLockConsentGateTests: XCTestCase {
    func testFreshConsentEnablesAndResetsCancellationCount() {
        var gate = LocalLockConsentGate(isEnabled: true, countdownCancellationCount: 2)

        gate.enableAfterFreshLocalConsent()

        XCTAssertTrue(gate.isEnabled)
        XCTAssertEqual(gate.countdownCancellationCount, 0)
    }

    func testThirdCountdownCancellationFailsClosed() {
        var gate = LocalLockConsentGate(maximumCountdownCancellations: 3)
        gate.enableAfterFreshLocalConsent()

        XCTAssertTrue(gate.recordCountdownCancellation())
        XCTAssertTrue(gate.recordCountdownCancellation())
        XCTAssertFalse(gate.recordCountdownCancellation())
        XCTAssertFalse(gate.isEnabled)
        XCTAssertEqual(gate.countdownCancellationCount, 0)
    }
}

final class HomeAssistantWindDownTests: XCTestCase {
    func testOnlyFixedWindDownSceneCanBeEncodedIntoARequest() throws {
        let configuration = try HomeAssistantWindDownConfiguration(
            baseURL: URL(string: "http://homeassistant.local:8123")!
        )
        let request = try configuration.makeActivationRequest(token: "local-token")

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "http://homeassistant.local:8123/api/services/scene/turn_on")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer local-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(
            try JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: String],
            ["entity_id": "scene.offshift_wind_down"]
        )
    }

    func testHomeAssistantConfigurationRejectsUnsafeOrIncompleteValues() {
        XCTAssertThrowsError(try HomeAssistantWindDownConfiguration(baseURL: URL(string: "file:///tmp/scene")!))
        XCTAssertThrowsError(try HomeAssistantWindDownConfiguration(baseURL: URL(string: "https://user:password@homeassistant.local")!))
        XCTAssertThrowsError(try HomeAssistantWindDownConfiguration(baseURL: URL(string: "https://homeassistant.local?target=other")!))

        let configuration = try! HomeAssistantWindDownConfiguration(baseURL: URL(string: "https://homeassistant.local")!)
        XCTAssertThrowsError(try configuration.makeActivationRequest(token: "  "))
    }

    func testHomeAssistantOutcomesCoverSuccessRevokedCredentialsAndOfflineWithoutAutomaticRetry() async throws {
        XCTAssertEqual(WindDownSceneResponseMapper.map(statusCode: 200), .activated)
        XCTAssertEqual(WindDownSceneResponseMapper.map(statusCode: 401), .unauthorized)
        XCTAssertEqual(WindDownSceneResponseMapper.map(statusCode: 404), .sceneNotFound)
        XCTAssertEqual(WindDownSceneResponseMapper.map(statusCode: 503), .rejected(statusCode: 503))
        let calls = CallRecorder()
        let client = HomeAssistantWindDownClient { request in
            await calls.record(request)
            return .unavailable
        }
        let configuration = try HomeAssistantWindDownConfiguration(baseURL: URL(string: "http://homeassistant.local:8123")!)

        let outcome = await client.activate(configuration: configuration, token: "local-token")
        let callCount = await calls.count

        XCTAssertEqual(outcome, .unavailable)
        XCTAssertEqual(callCount, 1)
        XCTAssertTrue(outcome.userMessage.contains("Nothing was retried automatically"))
    }
}

private actor CallRecorder {
    private(set) var count = 0

    func record(_ request: URLRequest) {
        count += 1
    }
}

final class InterventionControllerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func protectAssessment() -> WorkPatternAssessment {
        WorkPatternAssessment(
            state: .protect,
            totalActiveDuration: 95 * 60,
            currentContinuousActiveDuration: 95 * 60,
            appSwitchCount: 0,
            reasons: [.protectContinuousActivity]
        )
    }

    func testCountdownCanBeCancelledBeforeAnyLockRequest() {
        let adapter = NeverLockingTestAdapter()
        let log = InMemoryShadowModeLog()
        let controller = InterventionController(lockAdapter: adapter, shadowLog: log)
        controller.apply(protectAssessment(), at: now)

        XCTAssertTrue(controller.startPreLockCountdown(at: now, duration: 30))
        XCTAssertTrue(controller.cancelPreLockCountdown(at: now.addingTimeInterval(10)))
        XCTAssertEqual(controller.tick(at: now.addingTimeInterval(31)), .noCountdown)
        XCTAssertTrue(adapter.requests.isEmpty)
        XCTAssertTrue(log.events.contains { $0.action == .countdownCancelled })
    }

    func testDefaultConfigurationSuppressesFiredCountdownBeforeAdapterRequest() {
        let adapter = NeverLockingTestAdapter()
        let log = InMemoryShadowModeLog()
        let controller = InterventionController(lockAdapter: adapter, shadowLog: log)
        controller.apply(protectAssessment(), at: now)
        XCTAssertTrue(controller.startPreLockCountdown(at: now, duration: 10))

        XCTAssertEqual(
            controller.tick(at: now.addingTimeInterval(10)),
            .suppressedByDisabledLockRule
        )
        XCTAssertTrue(adapter.requests.isEmpty)
        XCTAssertTrue(log.events.contains {
            $0.action == .lockSuppressed && $0.detail == "local lock-screen rule is disabled"
        })
    }

    func testEnabledLocalLockRuleIsRequiredBeforeAdapterCanReceiveRequest() {
        let adapter = NeverLockingTestAdapter()
        let controller = InterventionController(
            lockAdapter: adapter,
            protectionConfiguration: ProtectionConfiguration(
                localLockScreenRule: LocalLockScreenRule(isEnabled: true)
            )
        )
        controller.apply(protectAssessment(), at: now)
        XCTAssertTrue(controller.startPreLockCountdown(at: now, duration: 10))

        XCTAssertEqual(
            controller.tick(at: now.addingTimeInterval(10)),
            .lockRequested(.notPerformed(reason: "No real lock adapter is installed."))
        )
        XCTAssertEqual(adapter.requests.count, 1)
    }

    func testEnabledRuleLimitsLockAttemptsToOnePerProtectEpisode() {
        let adapter = NeverLockingTestAdapter()
        let log = InMemoryShadowModeLog()
        let controller = InterventionController(
            lockAdapter: adapter,
            shadowLog: log,
            protectionConfiguration: ProtectionConfiguration(
                localLockScreenRule: LocalLockScreenRule(
                    isEnabled: true,
                    countdownDuration: 10,
                    maximumLockAttemptsPerProtectEpisode: 1
                )
            )
        )
        controller.apply(protectAssessment(), at: now)
        XCTAssertTrue(controller.startPreLockCountdown(at: now, duration: 10))
        XCTAssertEqual(
            controller.tick(at: now.addingTimeInterval(10)),
            .lockRequested(.notPerformed(reason: "No real lock adapter is installed."))
        )

        XCTAssertTrue(controller.startPreLockCountdown(at: now.addingTimeInterval(11), duration: 10))
        XCTAssertEqual(controller.tick(at: now.addingTimeInterval(21)), .suppressedByLockLimit)
        XCTAssertEqual(adapter.requests.count, 1)
        XCTAssertTrue(log.events.contains { $0.action == .lockSuppressed && $0.detail.contains("attempt limit") })
    }

    func testOnCallOverrideIsCappedAndLimitedPerProtectEpisode() {
        let controller = InterventionController(
            overridePolicy: OnCallOverridePolicy(maximumDuration: 60, maximumGrantsPerProtectEpisode: 1)
        )
        controller.apply(protectAssessment(), at: now)

        guard case let .granted(override) = controller.grantOnCallOverride(requestedDuration: 600, at: now) else {
            return XCTFail("Expected a granted override")
        }
        XCTAssertEqual(override.grantedDuration, 60)
        XCTAssertEqual(override.expiresAt, now.addingTimeInterval(60))
        XCTAssertEqual(
            controller.grantOnCallOverride(requestedDuration: 30, at: now.addingTimeInterval(1)),
            .rejected(reason: "Override grant limit reached for this protect episode.")
        )
    }

    func testExpiredOnCallOverrideStopsSuppressingTheProtectEpisode() {
        let controller = InterventionController(
            overridePolicy: OnCallOverridePolicy(maximumDuration: 60, maximumGrantsPerProtectEpisode: 1)
        )
        controller.apply(protectAssessment(), at: now)
        guard case .granted = controller.grantOnCallOverride(requestedDuration: 60, at: now) else {
            return XCTFail("Expected a granted override")
        }

        XCTAssertNotNil(controller.activeOverride)
        XCTAssertEqual(controller.tick(at: now.addingTimeInterval(60)), .noCountdown)
        XCTAssertNil(controller.activeOverride)
    }

    func testReturningToRoutineCancelsCountdownAndResetsIntervention() {
        let adapter = NeverLockingTestAdapter()
        let controller = InterventionController(lockAdapter: adapter)
        controller.apply(protectAssessment(), at: now)
        XCTAssertTrue(controller.startPreLockCountdown(at: now, duration: 10))

        controller.apply(
            WorkPatternAssessment(state: .routine, totalActiveDuration: 0, currentContinuousActiveDuration: 0, appSwitchCount: 0, reasons: [.noRecentActivity]),
            at: now.addingTimeInterval(5)
        )

        XCTAssertEqual(controller.state, .routine)
        XCTAssertEqual(controller.tick(at: now.addingTimeInterval(11)), .noCountdown)
        XCTAssertTrue(adapter.requests.isEmpty)
    }

    func testLocalShadowModeLogAppendsOnlyToItsSelectedLocalFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OffshiftCompanionCoreTests-\(UUID().uuidString)", isDirectory: true)
        let logURL = directory.appendingPathComponent("shadow.jsonl")
        defer { try? FileManager.default.removeItem(at: directory) }

        let log = LocalShadowModeLog(fileURL: logURL)
        log.append(ShadowModeEvent(timestamp: now, action: .assessment, detail: "fixture"))
        log.append(ShadowModeEvent(timestamp: now, action: .countdownCancelled, detail: "fixture"))

        let lines = try String(contentsOf: logURL, encoding: .utf8)
            .split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines.allSatisfy { $0.contains("fixture") })
    }
}
