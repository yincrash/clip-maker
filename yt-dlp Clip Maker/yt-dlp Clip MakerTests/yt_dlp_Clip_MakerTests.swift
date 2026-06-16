//
//  yt_dlp_Clip_MakerTests.swift
//  yt-dlp Clip MakerTests
//
//  Created by Mike Yin on 1/13/26.
//

import Testing
import Foundation
@testable import yt_dlp_Clip_Maker

// MARK: - DependencyStatus Tests

struct DependencyStatusTests {

    @Test func isReadyForInstalledStatus() {
        let installed = DependencyStatus.installed(version: "1.0", source: .appBundle)

        #expect(installed.isReady == true)
    }

    @Test func isReadyForSystemInstalledStatus() {
        let installed = DependencyStatus.installed(version: "1.0", source: .systemPath)

        #expect(installed.isReady == true)
    }

    @Test func isReadyFalseForOtherStatuses() {
        #expect(DependencyStatus.notInstalled.isReady == false)
        #expect(DependencyStatus.checking.isReady == false)
        #expect(DependencyStatus.downloading(progress: 0.5).isReady == false)
        #expect(DependencyStatus.foundInPath(path: "/usr/local/bin/yt-dlp", version: "1.0").isReady == false)
        #expect(DependencyStatus.error("test error").isReady == false)
    }

    @Test func versionExtraction() {
        let installed = DependencyStatus.installed(version: "2024.01.01", source: .appBundle)
        let notInstalled = DependencyStatus.notInstalled
        let foundInPath = DependencyStatus.foundInPath(path: "/usr/local/bin/yt-dlp", version: "2024.02.02")

        #expect(installed.version == "2024.01.01")
        #expect(notInstalled.version == nil)
        #expect(foundInPath.version == "2024.02.02")
    }
}

// MARK: - DependencySource Tests

struct DependencySourceTests {

    @Test func displayNames() {
        #expect(DependencySource.appBundle.displayName == "App")
        #expect(DependencySource.systemPath.displayName == "System")
    }
}

// MARK: - YtDlpVersion Tests

struct YtDlpVersionTests {

    /// Build a UTC date so comparisons don't drift with the test machine's time zone.
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func parsesStableVersion() {
        #expect(YtDlpVersion.releaseDate(from: "2026.06.09") == date(2026, 6, 9))
    }

    @Test func parsesNightlyVersionWithExtraComponents() {
        // Nightly builds append a build number; the date prefix should still parse.
        #expect(YtDlpVersion.releaseDate(from: "2026.06.09.232919") == date(2026, 6, 9))
    }

    @Test func parsesVersionWithWhitespace() {
        #expect(YtDlpVersion.releaseDate(from: "  2026.06.09\n") == date(2026, 6, 9))
    }

    @Test func rejectsNonDateVersions() {
        #expect(YtDlpVersion.releaseDate(from: "garbage") == nil)
        #expect(YtDlpVersion.releaseDate(from: "") == nil)
        #expect(YtDlpVersion.releaseDate(from: "2026.06") == nil)      // too few components
        #expect(YtDlpVersion.releaseDate(from: "2026.13.01") == nil)   // invalid month
        #expect(YtDlpVersion.releaseDate(from: "2026.06.40") == nil)   // invalid day
        #expect(YtDlpVersion.releaseDate(from: "1999.06.09") == nil)   // implausibly old
    }

    @Test func notOutdatedWhenRecent() {
        #expect(YtDlpVersion.isOutdated("2026.06.09", asOf: date(2026, 6, 15)) == false)
    }

    @Test func notOutdatedJustUnderThreshold() {
        // Two months after 2026.06.09 is 2026.08.09; the day before is still fresh.
        #expect(YtDlpVersion.isOutdated("2026.06.09", asOf: date(2026, 8, 8)) == false)
    }

    @Test func outdatedPastThreshold() {
        // One day past the two-month threshold.
        #expect(YtDlpVersion.isOutdated("2026.06.09", asOf: date(2026, 8, 10)) == true)
    }

    @Test func outdatedForVeryOldVersion() {
        #expect(YtDlpVersion.isOutdated("2025.01.01", asOf: date(2026, 6, 15)) == true)
    }

    @Test func unparseableVersionIsNeverOutdated() {
        // Fail safe: never nag about a build whose age we can't determine.
        #expect(YtDlpVersion.isOutdated("unknown", asOf: date(2026, 6, 15)) == false)
    }

    @Test func customThresholdIsRespected() {
        #expect(YtDlpVersion.isOutdated("2026.06.09", asOf: date(2026, 7, 25), months: 1) == true)
        #expect(YtDlpVersion.isOutdated("2026.06.09", asOf: date(2026, 6, 25), months: 1) == false)
    }

    @Test func ageDescriptionInMonths() {
        #expect(YtDlpVersion.ageDescription(for: "2026.06.09", asOf: date(2026, 9, 20)) == "3 months")
    }

    @Test func ageDescriptionSingularMonth() {
        #expect(YtDlpVersion.ageDescription(for: "2026.06.09", asOf: date(2026, 7, 20)) == "1 month")
    }

    @Test func ageDescriptionInYears() {
        #expect(YtDlpVersion.ageDescription(for: "2026.06.09", asOf: date(2027, 7, 1)) == "1 year")
    }

    @Test func ageDescriptionLessThanMonth() {
        #expect(YtDlpVersion.ageDescription(for: "2026.06.09", asOf: date(2026, 6, 20)) == "less than a month")
    }

    @Test func ageDescriptionNilForUnparseable() {
        #expect(YtDlpVersion.ageDescription(for: "nope") == nil)
    }
}

// MARK: - PathFinder Tests

struct PathFinderTests {

    @Test func mockPathFinderFindsBinary() {
        let mockFinder = MockPathFinder()
        mockFinder.addBinary("yt-dlp", at: "/usr/local/bin/yt-dlp")

        let result = mockFinder.findBinary(named: "yt-dlp")

        #expect(result != nil)
        #expect(result?.path == "/usr/local/bin/yt-dlp")
    }

    @Test func mockPathFinderReturnsNilForUnknownBinary() {
        let mockFinder = MockPathFinder()

        let result = mockFinder.findBinary(named: "unknown")

        #expect(result == nil)
    }

    @Test func mockPathFinderFileExists() {
        let mockFinder = MockPathFinder()
        mockFinder.addExistingPath("/some/path/file")

        #expect(mockFinder.fileExists(at: URL(fileURLWithPath: "/some/path/file")) == true)
        #expect(mockFinder.fileExists(at: URL(fileURLWithPath: "/other/path")) == false)
    }
}
