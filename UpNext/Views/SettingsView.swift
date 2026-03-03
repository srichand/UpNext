import EventKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    var calendarManager: CalendarManager
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var groupedCalendars: [(String, [EKCalendar])] {
        Dictionary(grouping: calendarManager.availableCalendars) { $0.source.title }
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
    }

    var body: some View {
        TabView {
            calendarsTab
                .tabItem {
                    Label("Calendars", systemImage: "calendar")
                }

            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
        }
        .frame(minWidth: 380, minHeight: 420)
    }

    // MARK: - Calendars Tab

    private var calendarsTab: some View {
        Group {
            if calendarManager.availableCalendars.isEmpty {
                ContentUnavailableView(
                    "No Calendars",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("Grant calendar access in System Settings \u{2192} Privacy & Security \u{2192} Calendars.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Form {
                    ForEach(groupedCalendars, id: \.0) { account, calendars in
                        Section(account) {
                            ForEach(calendars, id: \.calendarIdentifier) { calendar in
                                Toggle(isOn: calendarBinding(for: calendar)) {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color(cgColor: calendar.cgColor))
                                            .frame(width: 10, height: 10)
                                        Text(calendar.title)
                                    }
                                }
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        // Revert if registration fails
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Helpers

    private func calendarBinding(for calendar: EKCalendar) -> Binding<Bool> {
        Binding(
            get: { calendarManager.selectedCalendarIDs.contains(calendar.calendarIdentifier) },
            set: { isOn in
                if isOn {
                    calendarManager.selectedCalendarIDs.insert(calendar.calendarIdentifier)
                } else {
                    calendarManager.selectedCalendarIDs.remove(calendar.calendarIdentifier)
                }
            }
        )
    }
}
