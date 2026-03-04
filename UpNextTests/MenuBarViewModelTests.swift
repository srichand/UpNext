import XCTest
@testable import UpNext

final class MenuBarViewModelTests: XCTestCase {
    @MainActor
    func testMenuBarTextShowsNoMoreMeetingsWhenNoUpcomingEvents() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let viewModel = makeViewModel(now: now, events: [])

        XCTAssertEqual(viewModel.menuBarText, "No more meetings")
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
    private func makeViewModel(now: Date, events: [CalendarEvent]) -> MenuBarViewModel {
        let calendarManager = CalendarManager(
            startNotificationObserver: false,
            startPeriodicRefresh: false
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
}
