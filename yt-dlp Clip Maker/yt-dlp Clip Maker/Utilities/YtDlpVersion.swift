import Foundation

/// Utilities for interpreting yt-dlp's date-based version strings (e.g. "2026.06.09").
///
/// yt-dlp ships releases very frequently and YouTube routinely changes things in ways
/// that break older versions. A build more than a couple of months old is a strong
/// signal that downloads may start failing, so we parse the `YYYY.MM.DD` version into
/// a release date and decide whether it's stale enough to warn the user about.
enum YtDlpVersion {
    /// Age (in months) past which a yt-dlp build is considered outdated.
    static let outdatedThresholdMonths = 2

    /// A fixed UTC Gregorian calendar so parsing/comparisons don't drift with the
    /// user's locale or time zone (yt-dlp version dates are effectively UTC).
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    /// Parse a yt-dlp version string into its release date.
    ///
    /// Handles stable releases ("2026.06.09") and nightly/dev builds that append extra
    /// components ("2026.06.09.232919"). Returns nil if the string doesn't begin with a
    /// plausible `YYYY.MM.DD` date.
    static func releaseDate(from version: String) -> Date? {
        let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ".").prefix(3).compactMap { Int($0) }
        guard parts.count == 3 else { return nil }

        let (year, month, day) = (parts[0], parts[1], parts[2])
        guard year >= 2000, (1...12).contains(month), (1...31).contains(day) else { return nil }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)
    }

    /// Whether `version` is older than `months` months as of `now`.
    ///
    /// Returns false for versions we can't parse, so we never nag about a build whose
    /// age is unknown (e.g. a custom or source build).
    static func isOutdated(
        _ version: String,
        asOf now: Date = Date(),
        months: Int = outdatedThresholdMonths
    ) -> Bool {
        guard let releaseDate = releaseDate(from: version),
              let threshold = calendar.date(byAdding: .month, value: months, to: releaseDate) else {
            return false
        }
        return now > threshold
    }

    /// Approximate human-readable age of the build, e.g. "3 months" or "1 year".
    /// Returns nil for versions we can't parse.
    static func ageDescription(for version: String, asOf now: Date = Date()) -> String? {
        guard let releaseDate = releaseDate(from: version), now >= releaseDate else { return nil }

        let components = calendar.dateComponents([.year, .month], from: releaseDate, to: now)
        let years = components.year ?? 0
        let months = components.month ?? 0

        if years > 0 {
            return "\(years) \(years == 1 ? "year" : "years")"
        }
        if months > 0 {
            return "\(months) \(months == 1 ? "month" : "months")"
        }
        return "less than a month"
    }
}
