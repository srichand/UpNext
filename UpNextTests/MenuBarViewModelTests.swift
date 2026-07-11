import EventKit
import XCTest
@testable import UpNextCore

final class MenuBarViewModelTests: XCTestCase {
    @MainActor
    func testMenuBarTextShowsNoMoreMeetingsWhenNoUpcomingEvents() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let viewModel = makeViewModel(now: now, events: [])

        XCTAssertEqual(viewModel.menuBarText, "No more meetings")
    }

    @MainActor
    func testMenuBarTextExplainsWhenCalendarAccessIsDenied() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let viewModel = makeViewModel(now: now, events: [], authorizationStatus: .denied)

        XCTAssertTrue(viewModel.needsCalendarAccess)
        XCTAssertEqual(viewModel.menuBarText, "Calendar access needed")
    }

    @MainActor
    func testMenuBarTextShowsNowForInProgressEvent() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let event = makeEvent(
            id: "in-progress",
            title: "Daily Standup",
            start: now.addingTimeInterval(-5 * 60),
            end: now.addingTimeInterval(25 * 60)
        )
        let viewModel = makeViewModel(now: now, events: [event])

        XCTAssertEqual(viewModel.menuBarText, "Daily Standup (now)")
    }

    @MainActor
    func testMenuBarTextShowsRelativeTimeForUpcomingEvent() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let event = makeEvent(
            id: "upcoming",
            title: "Planning",
            start: now.addingTimeInterval((2 * 60 * 60) + (10 * 60)),
            end: now.addingTimeInterval((3 * 60 * 60) + (10 * 60))
        )
        let viewModel = makeViewModel(now: now, events: [event])

        XCTAssertEqual(viewModel.menuBarText, "Planning in 2h 10m")
    }

    @MainActor
    func testUpcomingEventsFiltersCompletedEvents() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let finished = makeEvent(
            id: "finished",
            title: "Finished",
            start: now.addingTimeInterval(-60 * 60),
            end: now.addingTimeInterval(-30 * 60)
        )
        let active = makeEvent(
            id: "active",
            title: "Active",
            start: now.addingTimeInterval(-10 * 60),
            end: now.addingTimeInterval(20 * 60)
        )
        let next = makeEvent(
            id: "next",
            title: "Next",
            start: now.addingTimeInterval(90 * 60),
            end: now.addingTimeInterval(120 * 60)
        )
        let viewModel = makeViewModel(now: now, events: [finished, active, next])

        XCTAssertEqual(viewModel.upcomingEvents.map(\.id), ["active", "next"])
        XCTAssertEqual(viewModel.nextEvent?.id, "active")
    }

    @MainActor
    func testOlderDateQueryCannotOverwriteNewerSelectedDate() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let firstDate = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let secondDate = Calendar.current.date(byAdding: .day, value: 2, to: now)!
        let provider = ControlledDateEventsProvider()
        let viewModel = MenuBarViewModel(
            calendarManager: CalendarManager(
                startNotificationObserver: false,
                startPeriodicRefresh: false
            ),
            startRefreshTimer: false,
            requestAccessOnInit: false,
            nowProvider: { now },
            selectedDateEventsProvider: { date in await provider.events(for: date) }
        )

        viewModel.selectedDate = firstDate
        let firstStarted = await provider.waitForRequestCount(1)
        XCTAssertTrue(firstStarted)
        viewModel.selectedDate = secondDate
        let secondStarted = await provider.waitForRequestCount(2)
        XCTAssertTrue(secondStarted)

        let secondEvent = makeEvent(
            id: "second",
            title: "Second date",
            start: secondDate,
            end: secondDate.addingTimeInterval(60)
        )
        await provider.completeRequest(1, with: [secondEvent])
        await waitUntil { viewModel.selectedDateEvents.map(\.id) == ["second"] }

        let firstEvent = makeEvent(
            id: "first",
            title: "First date",
            start: firstDate,
            end: firstDate.addingTimeInterval(60)
        )
        await provider.completeRequest(0, with: [firstEvent])
        await Task.yield()

        XCTAssertEqual(viewModel.selectedDateEvents.map(\.id), ["second"])
    }

    @MainActor
    func testCalendarSelectionChangeRefreshesBrowsedDate() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let provider = ControlledDateEventsProvider()
        let calendarManager = CalendarManager(
            startNotificationObserver: false,
            startPeriodicRefresh: false,
            authorizationStatusProvider: { .fullAccess }
        )
        let viewModel = MenuBarViewModel(
            calendarManager: calendarManager,
            startRefreshTimer: false,
            requestAccessOnInit: false,
            nowProvider: { now },
            selectedDateEventsProvider: { date in await provider.events(for: date) }
        )

        viewModel.selectedDate = selectedDate
        let firstStarted = await provider.waitForRequestCount(1)
        XCTAssertTrue(firstStarted)
        await provider.completeRequest(0, with: [])

        calendarManager.selectedCalendarIDs = ["work"]
        let refreshStarted = await provider.waitForRequestCount(2)
        XCTAssertTrue(refreshStarted)
        await provider.completeRequest(1, with: [])
    }

    @MainActor
    private func makeViewModel(
        now: Date,
        events: [CalendarEvent],
        authorizationStatus: EKAuthorizationStatus = .fullAccess
    ) -> MenuBarViewModel {
        let calendarManager = CalendarManager(
            startNotificationObserver: false,
            startPeriodicRefresh: false,
            authorizationStatusProvider: { authorizationStatus }
        )
        calendarManager.events = events

        let viewModel = MenuBarViewModel(
            calendarManager: calendarManager,
            startRefreshTimer: false,
            requestAccessOnInit: false,
            nowProvider: { now }
        )
        viewModel.currentDate = now
        return viewModel
    }

    private func makeEvent(id: String, title: String, start: Date, end: Date) -> CalendarEvent {
        CalendarEvent(
            id: id,
            title: title,
            startDate: start,
            endDate: end
        )
    }

    @MainActor
    private func waitUntil(_ predicate: @escaping @MainActor () -> Bool) async {
        for _ in 0..<1_000 where !predicate() {
            await Task.yield()
        }
        XCTAssertTrue(predicate())
    }
}

private actor ControlledDateEventsProvider {
    private var requests: [CheckedContinuation<[CalendarEvent], Never>] = []

    func events(for date: Date) async -> [CalendarEvent] {
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
