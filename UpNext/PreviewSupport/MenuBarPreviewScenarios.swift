import Foundation
import SwiftUI

enum MenuBarPreviewScenario: String, CaseIterable {
    case activeMeeting = "active-meeting"
    case packedDay = "packed-day"
    case emptyDay = "empty-day"
}

enum MenuBarPreviewFactory {
    static let fixedNow: Date = {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: "2026-03-03T17:00:00Z") else {
            preconditionFailure("Failed to parse fixed preview date")
        }
        return date
    }()

    @MainActor
    static func makeViewModel(
        scenario: MenuBarPreviewScenario,
        now: Date = fixedNow
    ) -> MenuBarViewModel {
        let calendarManager = CalendarManager(
            startNotificationObserver: false,
            startPeriodicRefresh: false
        )
        calendarManager.events = events(for: scenario, now: now)

        let viewModel = MenuBarViewModel(
            calendarManager: calendarManager,
            startRefreshTimer: false,
            requestAccessOnInit: false,
            nowProvider: { now }
        )
        viewModel.currentDate = now
        return viewModel
    }

    static func events(
        for scenario: MenuBarPreviewScenario,
        now: Date = fixedNow
    ) -> [CalendarEvent] {
        switch scenario {
        case .activeMeeting:
            return [
                makeEvent(
                    id: "active",
                    title: "Daily Standup",
                    start: now.addingTimeInterval(-7 * 60),
                    end: now.addingTimeInterval(23 * 60),
                    location: "Zoom",
                    color: .coral
                ),
                makeEvent(
                    id: "next-1",
                    title: "Roadmap Planning",
                    start: now.addingTimeInterval(48 * 60),
                    end: now.addingTimeInterval(78 * 60),
                    location: "Conf Room A",
                    color: .blue
                ),
                makeEvent(
                    id: "next-2",
                    title: "1:1 with Alex",
                    start: now.addingTimeInterval((2 * 60 * 60) + (5 * 60)),
                    end: now.addingTimeInterval((2 * 60 * 60) + (35 * 60)),
                    location: nil,
                    color: .green
                )
            ]
        case .packedDay:
            return [
                makeEvent(
                    id: "soon",
                    title: "Design Review",
                    start: now.addingTimeInterval(12 * 60),
                    end: now.addingTimeInterval(42 * 60),
                    location: "War Room",
                    color: .mint
                ),
                makeEvent(
                    id: "later-1",
                    title: "Sprint Retro",
                    start: now.addingTimeInterval((1 * 60 * 60) + (20 * 60)),
                    end: now.addingTimeInterval((2 * 60 * 60) + (5 * 60)),
                    location: "Zoom",
                    color: .orange
                ),
                makeEvent(
                    id: "later-2",
                    title: "Partner Sync",
                    start: now.addingTimeInterval((3 * 60 * 60) + (10 * 60)),
                    end: now.addingTimeInterval((3 * 60 * 60) + (55 * 60)),
                    location: "Huddle 3",
                    color: .purple
                )
            ]
        case .emptyDay:
            return []
        }
    }

    private static func makeEvent(
        id: String,
        title: String,
        start: Date,
        end: Date,
        location: String?,
        color: Color
    ) -> CalendarEvent {
        CalendarEvent(
            id: id,
            title: title,
            startDate: start,
            endDate: end,
            location: location,
            calendarTitle: "Preview",
            calendarColor: color
        )
    }
}
