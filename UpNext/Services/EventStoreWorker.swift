@preconcurrency import EventKit
import SwiftUI

protocol EventStoreQuerying: Sendable {
    func requestFullAccess() async throws
    func calendars() async -> [CalendarDescriptor]
    func events(on date: Date, selectedCalendarIDs: Set<String>) async -> [CalendarEvent]
}

actor EventStoreWorker: EventStoreQuerying {
    private let eventStore = EKEventStore()

    func requestFullAccess() async throws {
        _ = try await eventStore.requestFullAccessToEvents()
    }

    func calendars() -> [CalendarDescriptor] {
        eventStore.calendars(for: .event)
            .map { calendar in
                CalendarDescriptor(
                    id: calendar.calendarIdentifier,
                    title: calendar.title,
                    sourceTitle: calendar.source.title,
                    color: .safeCalendarColor(calendar.cgColor)
                )
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func events(on date: Date, selectedCalendarIDs: Set<String>) -> [CalendarEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: nil
        )

        return eventStore.events(matching: predicate)
            .filter { !$0.isAllDay }
            .filter { selectedCalendarIDs.contains($0.calendar.calendarIdentifier) }
            .map(CalendarEvent.init)
            .sorted { $0.startDate < $1.startDate }
    }
}
