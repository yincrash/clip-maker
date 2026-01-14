import Foundation

/// Utilities for parsing and formatting time values
enum TimeFormatter {
    /// Parse a time string (HH:MM:SS or MM:SS) into TimeInterval
    static func parse(_ string: String) -> TimeInterval? {
        let components = string.split(separator: ":").compactMap { Int($0) }

        switch components.count {
        case 2:
            // MM:SS
            let minutes = components[0]
            let seconds = components[1]
            guard minutes >= 0, seconds >= 0, seconds < 60 else { return nil }
            return TimeInterval(minutes * 60 + seconds)

        case 3:
            // HH:MM:SS
            let hours = components[0]
            let minutes = components[1]
            let seconds = components[2]
            guard hours >= 0, minutes >= 0, minutes < 60, seconds >= 0, seconds < 60 else { return nil }
            return TimeInterval(hours * 3600 + minutes * 60 + seconds)

        default:
            return nil
        }
    }

    /// Format a TimeInterval as HH:MM:SS
    static func format(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    /// Format a TimeInterval as MM:SS (for shorter durations)
    static func formatShort(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Validate a time string format
    static func isValid(_ string: String) -> Bool {
        parse(string) != nil
    }
}
