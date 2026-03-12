import EventKit
import XCTest
@testable import UpNextCore

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

    @MainActor
    func testInitDoesNotSchedulePeriodicRefreshWithoutCalendarAccess() {
        let manager = CalendarManager(
            startNotificationObserver: false,
            startPeriodicRefresh: true,
            authorizationStatusProvider: { .denied }
        )

        XCTAssertFalse(manager.isPeriodicRefreshScheduled)
    }

    @MainActor
    func testFetchEventsClearsCachedEventsAndStopsPeriodicRefreshWhenAccessIsRevoked() {
        let status = AuthorizationStatusBox(.fullAccess)
        var manager: CalendarManager? = CalendarManager(
            startNotificationObserver: false,
            startPeriodicRefresh: true,
            authorizationStatusProvider: { status.value }
        )

        XCTAssertTrue(manager?.isPeriodicRefreshScheduled == true)

        manager?.events = [
            makeEvent(
                id: "revoked-access",
                title: "Planning",
                start: Date(timeIntervalSince1970: 1_700_000_000),
                end: Date(timeIntervalSince1970: 1_700_000_000 + 1_800)
            )
        ]

        status.value = .denied
        manager?.fetchEvents()

        XCTAssertTrue(manager?.events.isEmpty == true)
        XCTAssertFalse(manager?.isPeriodicRefreshScheduled == true)

        manager = nil
    }

    private func makeEvent(id: String, title: String, start: Date, end: Date) -> CalendarEvent {
        CalendarEvent(
            id: id,
            title: title,
            startDate: start,
            endDate: end
        )
    }
}

private final class AuthorizationStatusBox: @unchecked Sendable {
    var value: EKAuthorizationStatus

    init(_ value: EKAuthorizationStatus) {
        self.value = value
    }
}
