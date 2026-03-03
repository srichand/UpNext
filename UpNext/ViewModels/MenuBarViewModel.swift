import SwiftUI

@Observable
@MainActor
final class MenuBarViewModel {
    let calendarManager = CalendarManager()

    /// Tick updated every 30 s to drive recomputation of relative times.
    var currentDate = Date()

    private var refreshTimer: Timer?

    // MARK: - Derived state

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

    // MARK: - Init

    init() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.currentDate = Date()
            }
        }

        Task {
            await calendarManager.requestAccess()
            currentDate = Date()
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
