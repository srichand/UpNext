import EventKit
import SwiftUI

struct CalendarEvent: Identifiable, Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let calendarTitle: String
    let calendarColor: Color

    init(from ekEvent: EKEvent) {
        // Combine identifier + start time for a unique, deterministic ID
        // (handles recurring events with the same eventIdentifier)
        let identifier = ekEvent.eventIdentifier ?? UUID().uuidString
        self.id = "\(identifier)_\(Int(ekEvent.startDate.timeIntervalSince1970))"
        self.title = ekEvent.title ?? "Untitled"
        self.startDate = ekEvent.startDate
        self.endDate = ekEvent.endDate
        self.isAllDay = ekEvent.isAllDay
        self.location = ekEvent.location
        self.calendarTitle = ekEvent.calendar.title
        self.calendarColor = .safeCalendarColor(ekEvent.calendar.cgColor)
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        location: String? = nil,
        calendarTitle: String = "Calendar",
        calendarColor: Color = .secondary
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
        self.calendarTitle = calendarTitle
        self.calendarColor = calendarColor
    }
}

extension String {
    func truncated(to maxLength: Int) -> String {
        if count <= maxLength { return self }
        return String(prefix(maxLength - 1)) + "\u{2026}"
    }
}
