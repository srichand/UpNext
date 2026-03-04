@preconcurrency import EventKit
import SwiftUI

@Observable
@MainActor
final class CalendarManager {
    static let selectedCalendarIDsDefaultsKey = "selectedCalendarIDs"

    private let eventStore = EKEventStore()

    var events: [CalendarEvent] = []
    var availableCalendars: [EKCalendar] = []
    var authorizationStatus: EKAuthorizationStatus = .notDetermined

    var selectedCalendarIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(
                Array(selectedCalendarIDs),
                forKey: Self.selectedCalendarIDsDefaultsKey
            )
            fetchEvents()
        }
    }

    private var hasLoadedInitialSelection: Bool
    private var observerToken: Any?

    init(
        startNotificationObserver: Bool = true,
        startPeriodicRefresh: Bool = true
    ) {
        if let saved = UserDefaults.standard.stringArray(
            forKey: Self.selectedCalendarIDsDefaultsKey
        ) {
            self.selectedCalendarIDs = Set(saved)
            self.hasLoadedInitialSelection = true
        } else {
            self.selectedCalendarIDs = []
            self.hasLoadedInitialSelection = false
        }

        if startNotificationObserver {
            setupNotificationObserver()
        }
        if startPeriodicRefresh {
            setupPeriodicFetch()
        }
    }

    // MARK: - Access

    func requestAccess() async {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            if granted {
                loadCalendars()
                fetchEvents()
            }
        } catch {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        }
    }

    // MARK: - Calendars

    func loadCalendars() {
        availableCalendars = eventStore.calendars(for: .event)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        // First launch — select every calendar by default
        if !hasLoadedInitialSelection {
            selectedCalendarIDs = Set(availableCalendars.map(\.calendarIdentifier))
            hasLoadedInitialSelection = true
        }

        // Prune IDs for calendars that no longer exist
        let validIDs = Set(availableCalendars.map(\.calendarIdentifier))
        let pruned = selectedCalendarIDs.intersection(validIDs)
        if pruned != selectedCalendarIDs {
            selectedCalendarIDs = pruned
        }
    }

    // MARK: - Events

    func fetchEvents() {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: Date())
        guard let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: nil
        )

        let ekEvents = eventStore.events(matching: predicate)

        events = ekEvents
            .filter { !$0.isAllDay }
            .filter { selectedCalendarIDs.contains($0.calendar.calendarIdentifier) }
            .map { CalendarEvent(from: $0) }
            .sorted { $0.startDate < $1.startDate }
    }

    /// Returns events for the given date without mutating stored state.
    func eventsForDate(_ date: Date) -> [CalendarEvent] {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        guard let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }

        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: nil
        )

        let ekEvents = eventStore.events(matching: predicate)

        return ekEvents
            .filter { !$0.isAllDay }
            .filter { selectedCalendarIDs.contains($0.calendar.calendarIdentifier) }
            .map { CalendarEvent(from: $0) }
            .sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Observation

    private func setupNotificationObserver() {
        observerToken = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.loadCalendars()
                self?.fetchEvents()
            }
        }
    }

    private func setupPeriodicFetch() {
        // Re-fetch every 5 minutes as a safety net alongside the notification observer
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchEvents()
            }
        }
    }
}
