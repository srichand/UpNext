import ServiceManagement
import SwiftUI

struct SettingsView: View {
    var calendarManager: CalendarManager
    var appUpdater: AppUpdater
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private let projectURL = URL(string: "https://github.com/srichand/UpNext")!
    private let privacyURL = URL(string: "https://github.com/srichand/UpNext/blob/main/PRIVACY.md")!
    private let supportURL = URL(string: "https://github.com/srichand/UpNext/issues/new")!

    private var groupedCalendars: [(String, [CalendarDescriptor])] {
        Dictionary(grouping: calendarManager.availableCalendars) { $0.sourceTitle }
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
    }

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            calendarsTab
                .tabItem {
                    Label("Calendars", systemImage: "calendar")
                }
        }
        .frame(width: 440, height: 380)
        .tint(.coral)
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
                            ForEach(calendars) { calendar in
                                Toggle(isOn: calendarBinding(for: calendar)) {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(calendar.color)
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
            Section("Startup") {
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

            Section("Updates") {
                if appUpdater.isConfigured {
                    Button("Check for Updates…") {
                        appUpdater.checkForUpdates()
                    }

                    Toggle(
                        "Automatically Check for Updates",
                        isOn: automaticUpdateChecksBinding
                    )

                    Toggle(
                        "Automatically Download Updates",
                        isOn: automaticUpdateDownloadsBinding
                    )
                    .disabled(!appUpdater.allowsAutomaticUpdates)
                } else {
                    Text(appUpdater.configurationMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("About") {
                LabeledContent("Version", value: versionDescription)
                Link("Project Website", destination: projectURL)
                Link("Privacy Policy", destination: privacyURL)
                Link("Report an Issue", destination: supportURL)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Helpers

    private func calendarBinding(for calendar: CalendarDescriptor) -> Binding<Bool> {
        Binding(
            get: { calendarManager.selectedCalendarIDs.contains(calendar.id) },
            set: { isOn in
                if isOn {
                    calendarManager.selectedCalendarIDs.insert(calendar.id)
                } else {
                    calendarManager.selectedCalendarIDs.remove(calendar.id)
                }
            }
        )
    }

    private var automaticUpdateChecksBinding: Binding<Bool> {
        Binding(
            get: { appUpdater.automaticallyChecksForUpdates },
            set: { appUpdater.automaticallyChecksForUpdates = $0 }
        )
    }

    private var automaticUpdateDownloadsBinding: Binding<Bool> {
        Binding(
            get: { appUpdater.automaticallyDownloadsUpdates },
            set: { appUpdater.automaticallyDownloadsUpdates = $0 }
        )
    }

    private var versionDescription: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = info["CFBundleVersion"] as? String ?? ""

        guard !build.isEmpty else { return version }
        return "\(version) (\(build))"
    }
}
