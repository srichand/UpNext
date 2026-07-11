import SwiftUI
import XCTest
@testable import UpNextCore

@MainActor
final class MenuBarPopoverTests: XCTestCase {
    func testBodyDoesNotRefetchLoadedNonTodayEvents() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        let queryCounter = QueryCounter()
        let expectedEvents = [
            makeEvent(
                id: "planning",
                title: "Planning",
                start: selectedDate.addingTimeInterval(9 * 60 * 60),
                end: selectedDate.addingTimeInterval(10 * 60 * 60)
            )
        ]

        let viewModel = MenuBarViewModel(
            calendarManager: CalendarManager(
                startNotificationObserver: false,
                startPeriodicRefresh: false
            ),
            startRefreshTimer: false,
            requestAccessOnInit: false,
            nowProvider: { now },
            selectedDateEventsProvider: { _ in
                queryCounter.count += 1
                return expectedEvents
            }
        )
        viewModel.selectedDate = selectedDate

        for _ in 0..<1_000 where queryCounter.count == 0 {
            await Task.yield()
        }
        XCTAssertEqual(queryCounter.count, 1)

        _ = MenuBarPopover(viewModel: viewModel).body

        XCTAssertEqual(queryCounter.count, 1)
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

private final class QueryCounter: @unchecked Sendable {
    var count = 0
}
