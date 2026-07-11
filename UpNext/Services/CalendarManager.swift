@preconcurrency import EventKit
import SwiftUI

@Observable
@MainActor
final class CalendarManager {
    static let selectedCalendarIDsDefaultsKey = "selectedCalendarIDs"
    static let dataDidChangeNotification = Notification.Name("CalendarManagerDataDidChange")

    private let eventStoreQuery: any EventStoreQuerying
    private let authorizationStatusProvider: @Sendable () -> EKAuthorizationStatus
    private let shouldStartPeriodicRefresh: Bool

    var events: [CalendarEvent] = []
    var availableCalendars: [CalendarDescriptor] = []
    var authorizationStatus: EKAuthorizationStatus

    var selectedCalendarIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(
                Array(selectedCalendarIDs),
                forKey: Self.selectedCalendarIDsDefaultsKey
            )
            NotificationCenter.default.post(name: Self.dataDidChangeNotification, object: self)
            fetchEvents()
        }
    }

    private var hasLoadedInitialSelection: Bool
    private var eventFetchGeneration = 0
    private var calendarLoadGeneration = 0
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
        },
        eventStoreQuery: any EventStoreQuerying = EventStoreWorker()
    ) {
        self.authorizationStatusProvider = authorizationStatusProvider
        self.shouldStartPeriodicRefresh = startPeriodicRefresh
        self.authorizationStatus = authorizationStatusProvider()
        self.eventStoreQuery = eventStoreQuery

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
            try await eventStoreQuery.requestFullAccess()
        } catch {
            // Fall through and refresh authorization state below.
        }

        refreshAuthorizationStatus()

        guard hasCalendarReadAccess else {
            clearCachedCalendarData()
            return
        }

        await loadCalendars()
        fetchEvents()
    }

    // MARK: - Calendars

    func loadCalendars() async {
        refreshAuthorizationStatus()

        guard hasCalendarReadAccess else {
            clearCachedCalendarData()
            return
        }

        calendarLoadGeneration += 1
        let generation = calendarLoadGeneration
        let loadedCalendars = await eventStoreQuery.calendars()

        refreshAuthorizationStatus()
        guard generation == calendarLoadGeneration, hasCalendarReadAccess else {
            if !hasCalendarReadAccess {
                clearCachedCalendarData()
            }
            return
        }

        availableCalendars = loadedCalendars

        // First launch — select every calendar by default
        if !hasLoadedInitialSelection {
            selectedCalendarIDs = Set(availableCalendars.map(\.id))
            hasLoadedInitialSelection = true
        }

        // Prune IDs for calendars that no longer exist
        let validIDs = Set(availableCalendars.map(\.id))
        let pruned = selectedCalendarIDs.intersection(validIDs)
        if pruned != selectedCalendarIDs {
            selectedCalendarIDs = pruned
        }
    }

    // MARK: - Events

    func fetchEvents() {
        refreshAuthorizationStatus()

        guard hasCalendarReadAccess else {
            clearCachedCalendarData()
            return
        }

        eventFetchGeneration += 1
        let generation = eventFetchGeneration
        let selectedIDs = selectedCalendarIDs
        let query = eventStoreQuery

        Task { [weak self] in
            let fetchedEvents = await query.events(
                on: Date(),
                selectedCalendarIDs: selectedIDs
            )

            guard let self, generation == self.eventFetchGeneration else { return }
            self.events = fetchedEvents
        }
    }

    /// Returns events for the given date without mutating stored state.
    func eventsForDate(_ date: Date) async -> [CalendarEvent] {
        refreshAuthorizationStatus()

        guard hasCalendarReadAccess else {
            return []
        }

        let fetchedEvents = await eventStoreQuery.events(
            on: date,
            selectedCalendarIDs: selectedCalendarIDs
        )

        refreshAuthorizationStatus()
        guard hasCalendarReadAccess else {
            clearCachedCalendarData()
            return []
        }

        return fetchedEvents
    }

    // MARK: - Observation

    private func setupNotificationObserver() {
        observerToken = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
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

        Task { [weak self] in
            guard let self else { return }
            await self.loadCalendars()
            self.fetchEvents()
            NotificationCenter.default.post(name: Self.dataDidChangeNotification, object: self)
        }
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
        eventFetchGeneration += 1
        calendarLoadGeneration += 1
        availableCalendars = []
        events = []
    }
}
