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
