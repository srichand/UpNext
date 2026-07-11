import SwiftUI

@Observable
@MainActor
final class MenuBarViewModel {
    let calendarManager: CalendarManager
    private let nowProvider: @Sendable () -> Date
    private let selectedDateEventsProvider: @MainActor @Sendable (Date) async -> [CalendarEvent]
    private var selectedDateFetchGeneration = 0

    /// Tick updated every 30 s to drive recomputation of relative times.
    var currentDate: Date

    /// The date currently being browsed in the popover. Defaults to today.
    var selectedDate: Date {
        didSet { loadSelectedDateEvents() }
    }

    private(set) var browsedDateEvents: [CalendarEvent] = []
    private(set) var isLoadingSelectedDateEvents = false

    @ObservationIgnored
    nonisolated(unsafe) private var refreshTimer: Timer?
    @ObservationIgnored
    nonisolated(unsafe) private var calendarDataObserverToken: Any?

    // MARK: - Derived state (menu bar — always today)

    var upcomingEvents: [CalendarEvent] {
        calendarManager.events.filter { $0.endDate > currentDate }
    }

    var nextEvent: CalendarEvent? {
        upcomingEvents.first
    }

    var needsCalendarAccess: Bool {
        calendarManager.authorizationStatus != .fullAccess
    }

    var menuBarText: String {
        guard !needsCalendarAccess else { return "Calendar access needed" }
        guard let next = nextEvent else { return "No more meetings" }
        let title = next.title.truncated(to: 20)
        if next.startDate <= currentDate {
            return "\(title) (now)"
        }
        return "\(title) in \(relativeTimeString(for: next.startDate))"
    }

    // MARK: - Derived state (popover — selected date)

    var isSelectedDateToday: Bool {
        Calendar.current.isDate(selectedDate, inSameDayAs: currentDate)
    }

    var selectedDateEvents: [CalendarEvent] {
        if isSelectedDateToday {
            return calendarManager.events.filter { $0.endDate > currentDate }
        } else {
            return browsedDateEvents
        }
    }

    var selectedDateHeaderString: String {
        if isSelectedDateToday { return "Today" }
        if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: currentDate),
           Calendar.current.isDate(selectedDate, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: currentDate),
           Calendar.current.isDate(selectedDate, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
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
        selectedDate = nowProvider()
    }

    func resetToToday() {
        selectedDate = nowProvider()
    }

    // MARK: - Init

    init(
        calendarManager: CalendarManager = CalendarManager(),
        startRefreshTimer: Bool = true,
        requestAccessOnInit: Bool = true,
        nowProvider: @escaping @Sendable () -> Date = Date.init,
        selectedDateEventsProvider: (@MainActor @Sendable (Date) async -> [CalendarEvent])? = nil
    ) {
        self.calendarManager = calendarManager
        self.nowProvider = nowProvider
        self.selectedDateEventsProvider = selectedDateEventsProvider ?? { await calendarManager.eventsForDate($0) }
        let initialDate = nowProvider()
        self.currentDate = initialDate
        self.selectedDate = initialDate

        calendarDataObserverToken = NotificationCenter.default.addObserver(
            forName: CalendarManager.dataDidChangeNotification,
            object: calendarManager,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.loadSelectedDateEvents()
            }
        }

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

    deinit {
        if let calendarDataObserverToken {
            NotificationCenter.default.removeObserver(calendarDataObserverToken)
        }
        refreshTimer?.invalidate()
    }

    private func loadSelectedDateEvents() {
        selectedDateFetchGeneration += 1
        let generation = selectedDateFetchGeneration

        guard !isSelectedDateToday else {
            browsedDateEvents = []
            isLoadingSelectedDateEvents = false
            return
        }

        let date = selectedDate
        isLoadingSelectedDateEvents = true

        Task { [weak self] in
            guard let self else { return }
            let fetchedEvents = await self.selectedDateEventsProvider(date)
            guard generation == self.selectedDateFetchGeneration,
                  Calendar.current.isDate(self.selectedDate, inSameDayAs: date) else { return }
            self.browsedDateEvents = fetchedEvents
            self.isLoadingSelectedDateEvents = false
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
