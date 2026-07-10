import AppKit
import SwiftUI

struct MenuBarPopover: View {
    let viewModel: MenuBarViewModel
    private let resetsInitialFocus: Bool
    @Environment(\.openSettings) private var openSettingsAction

    init(viewModel: MenuBarViewModel, resetsInitialFocus: Bool = true) {
        self.viewModel = viewModel
        self.resetsInitialFocus = resetsInitialFocus
    }

    var body: some View {
        // Resolve once so non-today renders do not re-query EventKit multiple times.
        let selectedDateEvents = viewModel.selectedDateEvents

        VStack(alignment: .leading, spacing: 0) {
            dateNavigationHeader

            Divider()

            if viewModel.needsCalendarAccess {
                calendarAccessState
            } else if selectedDateEvents.isEmpty {
                emptyState
            } else {
                eventList(selectedDateEvents)
            }

            Divider()
            footerButtons
        }
        .frame(width: 320)
        .background {
            if resetsInitialFocus {
                InitialFocusResetter()
            }
        }
        .onDisappear {
            viewModel.resetToToday()
        }
    }

    // MARK: - Subviews

    private var dateNavigationHeader: some View {
        HStack {
            Button(action: viewModel.goToPreviousDay) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.medium))
                    .frame(width: 30, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Previous day")

            Spacer()

            VStack(spacing: 4) {
                Text(viewModel.selectedDateHeaderString)
                    .font(.headline)

                if !viewModel.isSelectedDateToday {
                    Button {
                        viewModel.goToToday()
                    } label: {
                        Text("Today")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.coral, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            Button(action: viewModel.goToNextDay) {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.medium))
                    .frame(width: 30, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Next day")
        }
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(viewModel.emptyStateText)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var calendarAccessState: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("Calendar access required")
                .font(.headline)

            Text("Allow UpNext to read your calendars in System Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                openSettings()
            } label: {
                Text("Open UpNext Settings…")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.coral, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    private func eventList(_ selectedDateEvents: [CalendarEvent]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(selectedDateEvents.enumerated()), id: \.element.id) { index, event in
                EventRow(event: event, viewModel: viewModel)

                if index < selectedDateEvents.count - 1 {
                    Divider()
                        .padding(.horizontal, 12)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var footerButtons: some View {
        HStack {
            Button {
                openSettings()
            } label: {
                Label("Settings\u{2026}", systemImage: "gearshape")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .font(.callout)
        .controlSize(.small)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }

    private func openSettings() {
        openSettingsAction()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

private struct InitialFocusResetter: NSViewRepresentable {
    func makeNSView(context: Context) -> InitialFocusResettingView {
        InitialFocusResettingView()
    }

    func updateNSView(_ nsView: InitialFocusResettingView, context: Context) {}
}

private final class InitialFocusResettingView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        DispatchQueue.main.async { [weak self] in
            self?.window?.makeFirstResponder(nil)
        }
    }
}

// MARK: - Event Row

struct EventRow: View {
    let event: CalendarEvent
    let viewModel: MenuBarViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.calendarColor)
                .frame(width: 4)
                .padding(.vertical, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)

                Text(viewModel.timeRangeString(for: event))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let location = event.location, !location.isEmpty {
                    Label(location, systemImage: "location.fill")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if viewModel.isSelectedDateToday, event.id == viewModel.nextEvent?.id {
                Text(statusLabel)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(statusForegroundStyle)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(statusBackgroundStyle, in: Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private var statusLabel: String {
        if isCurrentEvent {
            return "Now"
        }
        return "in \(viewModel.relativeTimeString(for: event.startDate))"
    }

    private var statusForegroundStyle: AnyShapeStyle {
        if isCurrentEvent {
            return AnyShapeStyle(.white)
        }
        return AnyShapeStyle(.primary)
    }

    private var statusBackgroundStyle: AnyShapeStyle {
        if isCurrentEvent {
            return AnyShapeStyle(Color.red)
        }
        if isStartingSoon {
            return AnyShapeStyle(Color.orange.opacity(0.16))
        }
        return AnyShapeStyle(.quaternary)
    }

    private var isCurrentEvent: Bool {
        event.startDate <= viewModel.currentDate
    }

    private var isStartingSoon: Bool {
        event.startDate.timeIntervalSince(viewModel.currentDate) <= 15 * 60
    }
}
