import XCTest
@testable import OffshiftCompanion

@MainActor
final class CompanionStoreOnboardingTests: XCTestCase {
    func testEmergencyEscapeIsIgnoredOutsideTheVisibleCareSurface() {
        XCTAssertFalse(
            EmergencyEscapeMonitorPolicy.shouldHandle(
                keyCode: 53,
                isProtectionVisible: false
            )
        )
    }

    func testEmergencyEscapeIsHandledWhenTheMonitorCoverCareSurfaceIsVisibleButNotKey() {
        XCTAssertTrue(
            EmergencyEscapeMonitorPolicy.shouldHandle(
                keyCode: 53,
                isProtectionVisible: true
            )
        )
    }

    func testEmergencyEscapeOnlyHandlesTheEscapeKey() {
        XCTAssertTrue(
            EmergencyEscapeMonitorPolicy.shouldHandle(
                keyCode: 53,
                isProtectionVisible: true
            )
        )
        XCTAssertFalse(
            EmergencyEscapeMonitorPolicy.shouldHandle(
                keyCode: 36,
                isProtectionVisible: true
            )
        )
    }

    func testFirstRunIsOffUntilTheUserCompletesOnboarding() {
        let suiteName = "OffshiftCompanionTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = CompanionStore(defaults: defaults)

        XCTAssertTrue(store.needsOnboarding)
        XCTAssertFalse(store.isOffshiftEnabled)

        store.completeOnboarding(enableLocalCare: true)

        XCTAssertFalse(store.needsOnboarding)
        XCTAssertTrue(store.isOffshiftEnabled)
    }

    func testNotNowCompletesOnboardingWithCareOff() {
        let suiteName = "OffshiftCompanionTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = CompanionStore(defaults: defaults)
        store.completeOnboarding(enableLocalCare: false)

        XCTAssertFalse(store.needsOnboarding)
        XCTAssertFalse(store.isOffshiftEnabled)
    }

    func testDeveloperCarePreviewPresentsEvenWhenFreshOnboardingKeepsCareOff() {
        let suiteName = "OffshiftCompanionTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = CompanionStore(defaults: defaults)
        var presentations = 0
        store.onProtectionRequested = { presentations += 1 }

        store.showDeveloperCarePreview()

        XCTAssertEqual(store.assessment.state, .protect)
        XCTAssertEqual(presentations, 1)
        XCTAssertFalse(store.isOffshiftEnabled)
    }

    func testTakeFivePausesAVisibleCareEpisodeForFiveMinutes() {
        let suiteName = "OffshiftCompanionTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = CompanionStore(defaults: defaults)
        store.completeOnboarding(enableLocalCare: true)

        store.takeFive()
        store.simulateLateSessionRisk()

        XCTAssertTrue(store.isPaused)
        XCTAssertEqual(store.assessment.state, .routine)
        XCTAssertTrue(store.localControlSummary.contains("paused until"))
    }

    func testTakeFiveCannotReopenCareWhenTheNextRiskTickArrives() {
        let suiteName = "OffshiftCompanionTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = CompanionStore(defaults: defaults)
        store.completeOnboarding(enableLocalCare: true)
        var presentations = 0
        store.onProtectionRequested = { presentations += 1 }

        store.simulateLateSessionRisk()
        XCTAssertEqual(presentations, 1)
        XCTAssertTrue(store.shouldKeepProtectionSurfacePresented)

        store.takeFive()
        store.protectionSurfaceDidDisappear()
        store.simulateLateSessionRisk()

        XCTAssertTrue(store.isPaused)
        XCTAssertFalse(store.shouldKeepProtectionSurfacePresented)
        XCTAssertEqual(presentations, 1)
    }
}
