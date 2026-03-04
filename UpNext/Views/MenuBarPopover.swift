import SwiftUI

struct MenuBarPopover: View {
    let viewModel: MenuBarViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            dateNavigationHeader

            Divider()

            if viewModel.selectedDateEvents.isEmpty {
                emptyState
            } else {
                eventList
            }

            Divider()
            footerButtons
        }
        .frame(width: 300)
        .onDisappear {
            viewModel.resetToToday()
        }
    }

    // MARK: - Subviews

    private var dateNavigationHeader: some View {
        HStack {
            Button(action: viewModel.goToPreviousDay) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

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
                    .font(.body.weight(.semibold))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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

    private var eventList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(viewModel.selectedDateEvents.enumerated()), id: \.element.id) { index, event in
                EventRow(event: event, viewModel: viewModel)

                if index < viewModel.selectedDateEvents.count - 1 {
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
                openWindow(id: "settings")
                NSApplication.shared.activate(ignoringOtherApps: true)
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
        .font(.caption)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Event Row

struct EventRow: View {
    let event: CalendarEvent
    let viewModel: MenuBarViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.calendarColor)
                .frame(width: 4)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.headline)
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
                    .fontWeight(.medium)
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.12), in: Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var statusLabel: String {
        if isCurrentEvent {
            return "Now"
        }
        return "in \(viewModel.relativeTimeString(for: event.startDate))"
    }

    private var statusColor: Color {
        isCurrentEvent ? .red : .coral
    }

    private var isCurrentEvent: Bool {
        event.startDate <= viewModel.currentDate
    }
}
