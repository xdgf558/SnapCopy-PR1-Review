import XCTest
@testable import SnapCopy

@MainActor
final class UsageLimiterTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var calendar: Calendar!
    private let today = Date(timeIntervalSince1970: 1_768_473_600)

    override func setUp() {
        super.setUp()
        suiteName = "UsageLimiterTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        calendar = nil
        super.tearDown()
    }

    func testFreeAllowsOneHundredCaptionGenerationsPerDay() {
        let limiter = UsageLimiter(defaults: defaults, calendar: calendar, now: today)

        for _ in 0..<100 {
            XCTAssertTrue(limiter.canGenerateCaption(for: .free, now: today))
            limiter.recordCaptionGeneration(for: .free, now: today)
        }

        XCTAssertFalse(limiter.canGenerateCaption(for: .free, now: today))
        XCTAssertEqual(limiter.captionGenerationsUsed(now: today), 100)
    }

    func testPlusCanContinueAfterFreeLimit() {
        let limiter = UsageLimiter(defaults: defaults, calendar: calendar, now: today)

        for _ in 0..<100 {
            limiter.recordCaptionGeneration(for: .free, now: today)
        }

        XCTAssertFalse(limiter.canGenerateCaption(for: .free, now: today))
        XCTAssertTrue(limiter.canGenerateCaption(for: .plus, now: today))
    }

    func testUsageResetsOnNextDay() {
        let limiter = UsageLimiter(defaults: defaults, calendar: calendar, now: today)
        limiter.recordCaptionGeneration(for: .free, now: today)

        let tomorrow = today.addingTimeInterval(86_400)

        XCTAssertEqual(limiter.captionGenerationsUsed(now: tomorrow), 0)
        XCTAssertTrue(limiter.canGenerateCaption(for: .free, now: tomorrow))
    }

    func testBasicImageEnhancementIsUnlimitedForFree() {
        let limiter = UsageLimiter(defaults: defaults, calendar: calendar, now: today)

        for _ in 0..<20 {
            XCTAssertTrue(limiter.canUseBasicImageEnhancement(for: .free, now: today))
            limiter.recordBasicImageEnhancement(for: .free, now: today)
        }

        XCTAssertTrue(limiter.canUseBasicImageEnhancement(for: .free, now: today))
        XCTAssertNil(EntitlementLevel.free.dailyBasicImageEnhancementLimit)
    }

    func testCloudEnhancementLocalLimitsMatchReservedPlans() {
        let limiter = UsageLimiter(defaults: defaults, calendar: calendar, now: today)

        XCTAssertFalse(limiter.canUseCloudEnhancement(for: .free, now: today))
        XCTAssertEqual(limiter.remainingCloudEnhancements(for: .free, now: today), 0)

        for _ in 0..<3 {
            XCTAssertTrue(limiter.canUseCloudEnhancement(for: .free, isTestUser: true, now: today))
            limiter.recordCloudEnhancement(for: .free, isTestUser: true, now: today)
        }

        XCTAssertFalse(limiter.canUseCloudEnhancement(for: .free, isTestUser: true, now: today))
        XCTAssertEqual(limiter.remainingCloudEnhancements(for: .free, isTestUser: true, now: today), 0)
        XCTAssertEqual(EntitlementLevel.plus.dailyCloudEnhancementLimit(), 20)
        XCTAssertEqual(EntitlementLevel.pro.dailyCloudEnhancementLimit(), 50)
    }

    func testUserIdentityManagerCreatesAndReusesKeychainBackedUUID() {
        let store = InMemoryUserIdentityStore()
        let firstManager = UserIdentityManager(store: store)
        let secondManager = UserIdentityManager(store: store)

        XCTAssertEqual(firstManager.appUserId, secondManager.appUserId)
        XCTAssertNotNil(UUID(uuidString: firstManager.appUserId.uuidString))
    }

    func testCloudEnhancementRequestKeepsReservedFields() {
        let appUserId = UUID()
        let request = CloudEnhancementRequestBuilder().makeRequest(
            appUserId: appUserId,
            plan: .pro,
            featureType: .captionDeepUnderstanding,
            sceneJson: #"{"scene":"pet"}"#,
            imageUploadEnabled: false,
            locale: "zh-Hans",
            targetPlatform: .xiaohongshu
        )

        XCTAssertEqual(request.appUserId, appUserId)
        XCTAssertEqual(request.plan, .pro)
        XCTAssertEqual(request.featureType, .captionDeepUnderstanding)
        XCTAssertEqual(request.sceneJson, #"{"scene":"pet"}"#)
        XCTAssertFalse(request.imageUploadEnabled)
        XCTAssertEqual(request.locale, "zh-Hans")
        XCTAssertEqual(request.targetPlatform, .xiaohongshu)
    }
}
