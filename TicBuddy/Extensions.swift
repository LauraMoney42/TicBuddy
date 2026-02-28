// TicBuddy — Extensions.swift
// Shared utility extensions used across views.

import SwiftUI

// MARK: - Color from Hex String

extension Color {
    /// Initialize a Color from a 6-digit hex string (e.g., "667EEA" or "#667EEA").
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers

extension View {
    /// Conditionally apply a modifier.
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Date Helpers

extension Date {
    /// Returns a short time string like "3:45 PM".
    var shortTimeString: String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        return fmt.string(from: self)
    }

    /// Returns a short date string like "Mon, Feb 25".
    var shortDateString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE, MMM d"
        return fmt.string(from: self)
    }

    /// Days since this date (positive = past, negative = future).
    var daysAgo: Int {
        Calendar.current.dateComponents([.day], from: self, to: Date()).day ?? 0
    }
}
