import SwiftUI
import AppKit

extension Color {
    /// Primary brand accent — warm coral from the app icon's "next event" dot.
    static let coral = Color(red: 0.96, green: 0.32, blue: 0.12) // #F4511E
    /// Lighter coral for subtle backgrounds and highlights.
    static let coralLight = Color(red: 1.0, green: 0.54, blue: 0.40) // #FF8A65

    /// Safely convert EventKit/AppKit calendar colors. Falls back when color space is unsupported.
    static func safeCalendarColor(_ cgColor: CGColor?) -> Color {
        guard let cgColor else { return .secondary }
        guard let nsColor = NSColor(cgColor: cgColor) else { return .secondary }
        return Color(nsColor)
    }
}
