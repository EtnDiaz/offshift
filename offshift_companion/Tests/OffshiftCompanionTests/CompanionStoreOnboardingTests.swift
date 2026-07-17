import XCTest
@testable import OffshiftCompanion

@MainActor
final class CompanionStoreOnboardingTests: XCTestCase {
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
}
