import XCTest
@testable import CVBoostaApp

final class ScanLimitServiceTests: XCTestCase {
    func testFreeUserCanOnlyScanOncePerDay() {
        let defaults = UserDefaults(suiteName: "ScanLimitServiceTests")!
        defaults.removePersistentDomain(forName: "ScanLimitServiceTests")

        let service = ScanLimitService(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let initial = service.status(isPremium: false, now: now)
        XCTAssertTrue(initial.canScan)
        XCTAssertEqual(initial.scansRemaining, 1)

        service.recordScan(isPremium: false, now: now)

        let afterFirst = service.status(isPremium: false, now: now)
        XCTAssertFalse(afterFirst.canScan)
        XCTAssertEqual(afterFirst.scansRemaining, 0)
    }

    func testFreeUserResetsNextDay() {
        let defaults = UserDefaults(suiteName: "ScanLimitServiceTestsReset")!
        defaults.removePersistentDomain(forName: "ScanLimitServiceTestsReset")

        let service = ScanLimitService(defaults: defaults)
        let dayOne = Date(timeIntervalSince1970: 1_700_000_000)
        let dayTwo = Date(timeIntervalSince1970: 1_700_086_400)

        service.recordScan(isPremium: false, now: dayOne)
        let dayOneStatus = service.status(isPremium: false, now: dayOne)
        XCTAssertFalse(dayOneStatus.canScan)

        let dayTwoStatus = service.status(isPremium: false, now: dayTwo)
        XCTAssertTrue(dayTwoStatus.canScan)
        XCTAssertEqual(dayTwoStatus.scansRemaining, 1)
    }

    func testPremiumAlwaysUnlimited() {
        let defaults = UserDefaults(suiteName: "ScanLimitServiceTestsPremium")!
        defaults.removePersistentDomain(forName: "ScanLimitServiceTestsPremium")

        let service = ScanLimitService(defaults: defaults)
        let status = service.status(isPremium: true)

        XCTAssertTrue(status.canScan)
        XCTAssertEqual(status.scansRemaining, Int.max)
    }
}
