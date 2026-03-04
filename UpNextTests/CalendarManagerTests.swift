import XCTest
@testable import UpNext

final class CalendarManagerTests: XCTestCase {
    private let defaultsKey = "selectedCalendarIDs"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        super.tearDown()
    }

    @MainActor
    func testInitLoadsSelectedCalendarIDsFromUserDefaults() {
        UserDefaults.standard.set(
            ["cal-1", "cal-2"],
            forKey: defaultsKey
        )

        let manager = CalendarManager(
            startNotificationObserver: false,
            startPeriodicRefresh: false
        )

        XCTAssertEqual(manager.selectedCalendarIDs, Set(["cal-1", "cal-2"]))
    }

    @MainActor
    func testInitStartsWithEmptySelectionWhenNoSavedValue() {
        let manager = CalendarManager(
            startNotificationObserver: false,
            startPeriodicRefresh: false
        )

        XCTAssertTrue(manager.selectedCalendarIDs.isEmpty)
    }

    @MainActor
    func testSettingSelectedCalendarIDsPersistsToUserDefaults() {
        let manager = CalendarManager(
            startNotificationObserver: false,
            startPeriodicRefresh: false
        )

        manager.selectedCalendarIDs = ["team-calendar", "personal-calendar"]

        let storedIDs = Set(
            UserDefaults.standard.stringArray(
                forKey: defaultsKey
            ) ?? []
        )
        XCTAssertEqual(storedIDs, Set(["team-calendar", "personal-calendar"]))
    }
}
