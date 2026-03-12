@preconcurrency import EventKit
import SwiftUI

@Observable
@MainActor
final class CalendarManager {
    static let selectedCalendarIDsDefaultsKey = "selectedCalendarIDs"

    private let eventStore = EKEventStore()
    private let authorizationStatusProvider: @Sendable () -> EKAuthorizationStatus
    private let shouldStartPeriodicRefresh: Bool

    var events: [CalendarEvent] = []
    var availableCalendars: [EKCalendar] = []
    var authorizationStatus: EKAuthorizationStatus

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
    @ObservationIgnored
    nonisolated(unsafe) private var observerToken: Any?
    @ObservationIgnored
    nonisolated(unsafe) private var periodicFetchTimer: Timer?

    var isPeriodicRefreshScheduled: Bool {
        periodicFetchTimer != nil
    }

    init(
        startNotificationObserver: Bool = true,
        startPeriodicRefresh: Bool = true,
        authorizationStatusProvider: @escaping @Sendable () -> EKAuthorizationStatus = {
            EKEventStore.authorizationStatus(for: .event)
        }
    ) {
        self.authorizationStatusProvider = authorizationStatusProvider
        self.shouldStartPeriodicRefresh = startPeriodicRefresh
        self.authorizationStatus = authorizationStatusProvider()

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
        setupPeriodicFetchIfNeeded()
    }

    deinit {
        if let observerToken {
            NotificationCenter.default.removeObserver(observerToken)
        }
        periodicFetchTimer?.invalidate()
    }

    // MARK: - Access

    func requestAccess() async {
        do {
            _ = try await eventStore.requestFullAccessToEvents()
        } catch {
            // Fall through and refresh authorization state below.
        }

        refreshAuthorizationStatus()

        guard hasCalendarReadAccess else {
            clearCachedCalendarData()
            return
        }

        loadCalendars()
        fetchEvents()
    }

    // MARK: - Calendars

    func loadCalendars() {
        refreshAuthorizationStatus()

        guard hasCalendarReadAccess else {
            clearCachedCalendarData()
            return
        }

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
        refreshAuthorizationStatus()

        guard hasCalendarReadAccess else {
            events = []
            return
        }

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
        refreshAuthorizationStatus()

        guard hasCalendarReadAccess else {
            return []
        }

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
                self?.handleEventStoreChange()
            }
        }
    }

    private func setupPeriodicFetchIfNeeded() {
        guard shouldStartPeriodicRefresh else { return }
        guard hasCalendarReadAccess else { return }
        guard periodicFetchTimer == nil else { return }

        // Re-fetch every 5 minutes as a safety net alongside the notification observer
        periodicFetchTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchEvents()
            }
        }
    }

    private func stopPeriodicFetch() {
        periodicFetchTimer?.invalidate()
        periodicFetchTimer = nil
    }

    private func handleEventStoreChange() {
        refreshAuthorizationStatus()

        guard hasCalendarReadAccess else {
            clearCachedCalendarData()
            return
        }

        loadCalendars()
        fetchEvents()
    }

    private func refreshAuthorizationStatus() {
        authorizationStatus = authorizationStatusProvider()

        if hasCalendarReadAccess {
            setupPeriodicFetchIfNeeded()
        } else {
            stopPeriodicFetch()
        }
    }

    private var hasCalendarReadAccess: Bool {
        authorizationStatus == .fullAccess
    }

    private func clearCachedCalendarData() {
        availableCalendars = []
        events = []
    }
}
