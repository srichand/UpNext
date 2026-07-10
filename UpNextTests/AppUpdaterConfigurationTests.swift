import XCTest
@testable import UpNextCore

final class AppUpdaterConfigurationTests: XCTestCase {
    func testConfigurationRecognizesPopulatedFeedAndPublicKey() {
        let publicKey = Data(repeating: 0xAB, count: 32).base64EncodedString()
        let configuration = AppUpdaterConfiguration(
            infoDictionary: [
                "SUFeedURL": "https://example.com/appcast.xml",
                "SUPublicEDKey": publicKey
            ]
        )

        XCTAssertTrue(configuration.isConfigured)
        XCTAssertEqual(configuration.feedURL, "https://example.com/appcast.xml")
        XCTAssertEqual(configuration.publicEDKey, publicKey)
        XCTAssertTrue(configuration.missingKeys.isEmpty)
    }

    func testConfigurationTreatsEmptyValuesAsMissing() {
        let configuration = AppUpdaterConfiguration(
            infoDictionary: [
                "SUFeedURL": "   ",
                "SUPublicEDKey": ""
            ]
        )

        XCTAssertFalse(configuration.isConfigured)
        XCTAssertEqual(configuration.missingKeys, ["SUFeedURL", "SUPublicEDKey"])
    }

    func testConfigurationTreatsUnresolvedBuildSettingsAsMissing() {
        let configuration = AppUpdaterConfiguration(
            infoDictionary: [
                "SUFeedURL": "$(SPARKLE_FEED_URL)",
                "SUPublicEDKey": "$(SPARKLE_PUBLIC_ED_KEY)"
            ]
        )

        XCTAssertFalse(configuration.isConfigured)
        XCTAssertEqual(configuration.missingKeys, ["SUFeedURL", "SUPublicEDKey"])
    }

    func testConfigurationRejectsInsecureFeedURL() {
        let configuration = AppUpdaterConfiguration(
            infoDictionary: [
                "SUFeedURL": "http://example.com/appcast.xml",
                "SUPublicEDKey": Data(repeating: 0xAB, count: 32).base64EncodedString()
            ]
        )

        XCTAssertNil(configuration.feedURL)
        XCTAssertEqual(configuration.missingKeys, ["SUFeedURL"])
    }

    func testConfigurationRejectsMalformedPublicKey() {
        let configuration = AppUpdaterConfiguration(
            infoDictionary: [
                "SUFeedURL": "https://example.com/appcast.xml",
                "SUPublicEDKey": "not-a-valid-ed25519-public-key"
            ]
        )

        XCTAssertNil(configuration.publicEDKey)
        XCTAssertEqual(configuration.missingKeys, ["SUPublicEDKey"])
    }
}
