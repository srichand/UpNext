import SwiftUI

@Observable
@MainActor
final class MenuBarViewModel {
    let calendarManager: CalendarManager
    private let nowProvider: () -> Date

    /// Tick updated every 30 s to drive recomputation of relative times.
    var currentDate: Date

    /// The date currently being browsed in the popover. Defaults to today.
    var selectedDate = Date()

    private var refreshTimer: Timer?

    // MARK: - Derived state (menu bar — always today)

    var upcomingEvents: [CalendarEvent] {
        calendarManager.events.filter { $0.endDate > currentDate }
    }

    var nextEvent: CalendarEvent? {
        upcomingEvents.first
    }

    var menuBarText: String {
        guard let next = nextEvent else { return "No more meetings" }
        let title = next.title.truncated(to: 20)
        if next.startDate <= currentDate {
            return "\(title) (now)"
        }
        return "\(title) in \(relativeTimeString(for: next.startDate))"
    }

    // MARK: - Derived state (popover — selected date)

    var isSelectedDateToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    var selectedDateEvents: [CalendarEvent] {
        if isSelectedDateToday {
            return calendarManager.events.filter { $0.endDate > currentDate }
        } else {
            return calendarManager.eventsForDate(selectedDate)
        }
    }

    var selectedDateHeaderString: String {
        if isSelectedDateToday { return "Today" }
        if Calendar.current.isDateInYesterday(selectedDate) { return "Yesterday" }
        if Calendar.current.isDateInTomorrow(selectedDate) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: selectedDate)
    }

    var emptyStateText: String {
        isSelectedDateToday ? "No more meetings today" : "No meetings on this day"
    }

    // MARK: - Day navigation

    func goToPreviousDay() {
        guard let newDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        selectedDate = newDate
    }

    func goToNextDay() {
        guard let newDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        selectedDate = newDate
    }

    func goToToday() {
        selectedDate = Date()
    }

    func resetToToday() {
        selectedDate = Date()
    }

    // MARK: - Init

    init(
        calendarManager: CalendarManager = CalendarManager(),
        startRefreshTimer: Bool = true,
        requestAccessOnInit: Bool = true,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.calendarManager = calendarManager
        self.nowProvider = nowProvider
        self.currentDate = nowProvider()

        if startRefreshTimer {
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.currentDate = nowProvider()
                }
            }
        }

        if requestAccessOnInit {
            Task {
                await calendarManager.requestAccess()
                currentDate = nowProvider()
            }
        }
    }

    // MARK: - Formatting helpers

    func relativeTimeString(for date: Date) -> String {
        let interval = date.timeIntervalSince(currentDate)
        guard interval > 0 else { return "now" }

        let totalMinutes = Int(ceil(interval / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        switch (hours, minutes) {
        case (0, let m):
            return "\(m)m"
        case (let h, 0):
            return "\(h)h"
        case (let h, let m):
            return "\(h)h \(m)m"
        }
    }

    func timeRangeString(for event: CalendarEvent) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let start = formatter.string(from: event.startDate)
        let end = formatter.string(from: event.endDate)
        return "\(start) \u{2013} \(end)"
    }
}
