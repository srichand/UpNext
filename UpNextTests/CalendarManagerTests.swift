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

    @MainActor
    func testFetchEventsDoesNotBlockMainActorWhileQueryIsSuspended() async {
        let store = ControlledEventStore()
        let manager = CalendarManager(
            startNotificationObserver: false,
            startPeriodicRefresh: false,
            authorizationStatusProvider: { .fullAccess },
            eventStoreQuery: store
        )

        manager.fetchEvents()
        let started = await store.waitForRequestCount(1)
        XCTAssertTrue(started)

        // Reaching this assertion while the query is suspended proves fetchEvents returned
        // control to the main actor instead of synchronously waiting on EventKit.
        XCTAssertTrue(manager.events.isEmpty)

        let fetchedEvent = makeEvent(
            id: "fetched",
            title: "Fetched asynchronously",
            start: Date(),
            end: Date().addingTimeInterval(60)
        )
        await store.completeRequest(0, with: [fetchedEvent])
        await waitUntil { manager.events.map(\.id) == ["fetched"] }
    }

    @MainActor
    func testOlderFetchCannotOverwriteNewerCalendarSelection() async {
        let store = ControlledEventStore()
        let manager = CalendarManager(
            startNotificationObserver: false,
            startPeriodicRefresh: false,
            authorizationStatusProvider: { .fullAccess },
            eventStoreQuery: store
        )

        manager.selectedCalendarIDs = ["old"]
        let firstStarted = await store.waitForRequestCount(1)
        XCTAssertTrue(firstStarted)
        manager.selectedCalendarIDs = ["new"]
        let secondStarted = await store.waitForRequestCount(2)
        XCTAssertTrue(secondStarted)

        let newEvent = makeEvent(
            id: "new",
            title: "New selection",
            start: Date(),
            end: Date().addingTimeInterval(60)
        )
        await store.completeRequest(1, with: [newEvent])
        await waitUntil { manager.events.map(\.id) == ["new"] }

        let oldEvent = makeEvent(
            id: "old",
            title: "Old selection",
            start: Date(),
            end: Date().addingTimeInterval(60)
        )
        await store.completeRequest(0, with: [oldEvent])
        await Task.yield()

        XCTAssertEqual(manager.events.map(\.id), ["new"])
    }

    @MainActor
    func testRevokingAccessInvalidatesInFlightEventQuery() async {
        let status = AuthorizationStatusBox(.fullAccess)
        let store = ControlledEventStore()
        let manager = CalendarManager(
            startNotificationObserver: false,
            startPeriodicRefresh: false,
            authorizationStatusProvider: { status.value },
            eventStoreQuery: store
        )

        manager.fetchEvents()
        let started = await store.waitForRequestCount(1)
        XCTAssertTrue(started)

        status.value = .denied
        manager.fetchEvents()

        let privateEvent = makeEvent(
            id: "private",
            title: "Should stay cleared",
            start: Date(),
            end: Date().addingTimeInterval(60)
        )
        await store.completeRequest(0, with: [privateEvent])
        await Task.yield()

        XCTAssertTrue(manager.events.isEmpty)
    }

    @MainActor
    func testRevokingAccessDiscardsInFlightBrowsedDateQuery() async {
        let status = AuthorizationStatusBox(.fullAccess)
        let store = ControlledEventStore()
        let manager = CalendarManager(
            startNotificationObserver: false,
            startPeriodicRefresh: false,
            authorizationStatusProvider: { status.value },
            eventStoreQuery: store
        )

        let query = Task { await manager.eventsForDate(Date()) }
        let started = await store.waitForRequestCount(1)
        XCTAssertTrue(started)
        status.value = .denied

        let privateEvent = makeEvent(
            id: "private-date",
            title: "Should not be returned",
            start: Date(),
            end: Date().addingTimeInterval(60)
        )
        await store.completeRequest(0, with: [privateEvent])

        let result = await query.value
        XCTAssertTrue(result.isEmpty)
    }

    @MainActor
    func testRevokingAccessInvalidatesInFlightCalendarLoad() async {
        let status = AuthorizationStatusBox(.fullAccess)
        let store = ControlledCalendarStore()
        let manager = CalendarManager(
            startNotificationObserver: false,
            startPeriodicRefresh: false,
            authorizationStatusProvider: { status.value },
            eventStoreQuery: store
        )

        let load = Task { await manager.loadCalendars() }
        let started = await store.waitForRequestCount(1)
        XCTAssertTrue(started)
        status.value = .denied
        await store.completeRequest(0, with: [
            CalendarDescriptor(id: "private", title: "Private", sourceTitle: "iCloud", color: .red)
        ])
        await load.value

        XCTAssertTrue(manager.availableCalendars.isEmpty)
        XCTAssertTrue(manager.selectedCalendarIDs.isEmpty)
    }

    @MainActor
    private func waitUntil(
        _ predicate: @escaping @MainActor () -> Bool
    ) async {
        for _ in 0..<1_000 where !predicate() {
            await Task.yield()
        }
        XCTAssertTrue(predicate())
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

private actor ControlledEventStore: EventStoreQuerying {
    private var requests: [CheckedContinuation<[CalendarEvent], Never>] = []

    func requestFullAccess() async throws {}
    func calendars() async -> [CalendarDescriptor] { [] }

    func events(on date: Date, selectedCalendarIDs: Set<String>) async -> [CalendarEvent] {
        await withCheckedContinuation { continuation in
            requests.append(continuation)
        }
    }

    func waitForRequestCount(_ count: Int) async -> Bool {
        for _ in 0..<1_000 where requests.count < count {
            await Task.yield()
        }
        return requests.count >= count
    }

    func completeRequest(_ index: Int, with events: [CalendarEvent]) {
        requests[index].resume(returning: events)
    }
}

private actor ControlledCalendarStore: EventStoreQuerying {
    private var requests: [CheckedContinuation<[CalendarDescriptor], Never>] = []

    func requestFullAccess() async throws {}

    func calendars() async -> [CalendarDescriptor] {
        await withCheckedContinuation { continuation in
            requests.append(continuation)
        }
    }

    func events(on date: Date, selectedCalendarIDs: Set<String>) async -> [CalendarEvent] { [] }

    func waitForRequestCount(_ count: Int) async -> Bool {
        for _ in 0..<1_000 where requests.count < count {
            await Task.yield()
        }
        return requests.count >= count
    }

    func completeRequest(_ index: Int, with calendars: [CalendarDescriptor]) {
        requests[index].resume(returning: calendars)
    }
}

private final class AuthorizationStatusBox: @unchecked Sendable {
    var value: EKAuthorizationStatus

    init(_ value: EKAuthorizationStatus) {
        self.value = value
    }
}
