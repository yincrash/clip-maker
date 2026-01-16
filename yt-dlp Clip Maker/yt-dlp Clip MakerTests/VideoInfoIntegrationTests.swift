//
//  VideoInfoIntegrationTests.swift
//  yt-dlp Clip MakerTests
//
//  Integration tests that verify video info fetching works with real URLs.
//  These tests require yt-dlp to be installed via Homebrew.
//

import Testing
import Foundation
@testable import yt_dlp_Clip_Maker

/// Integration tests for fetching video info from various platforms.
/// These tests hit real URLs and require network access and yt-dlp installed via Homebrew.
@MainActor
struct VideoInfoIntegrationTests {

    /// Creates a ClipService configured to use system-installed binaries
    private func makeClipService() async -> ClipService {
        let dependencyManager = DependencyManager()
        await dependencyManager.checkDependencies()

        // Use system binaries if available
        if dependencyManager.hasSystemYtDlp {
            dependencyManager.useSystemYtDlp()
        }
        if dependencyManager.hasSystemFfmpeg {
            dependencyManager.useSystemFfmpeg()
        }

        return ClipService(dependencyManager: dependencyManager)
    }

    // MARK: - YouTube

    @Test func fetchYouTubeVideoInfo() async throws {
        let clipService = await makeClipService()

        // Short, stable YouTube video (Big Buck Bunny trailer - public domain)
        let url = "https://www.youtube.com/watch?v=aqz-KE-bpKQ"

        let info = try await clipService.fetchVideoInfo(url: url)

        #expect(!info.id.isEmpty, "Video should have an ID")
        #expect(!info.title.isEmpty, "Video should have a title")
        #expect(info.duration > 0, "Video should have a duration")
        #expect(!info.formats.isEmpty, "Video should have formats")
        #expect(info.displayFormats.count > 0, "Video should have display formats")
    }

    // MARK: - YouTube (short video)

    @Test func fetchYouTubeShortVideoInfo() async throws {
        let clipService = await makeClipService()

        // Blender Foundation's Sintel trailer (public domain, stable)
        let url = "https://www.youtube.com/watch?v=eRsGyueVLvQ"

        let info = try await clipService.fetchVideoInfo(url: url)

        #expect(!info.id.isEmpty, "Video should have an ID")
        #expect(!info.title.isEmpty, "Video should have a title")
        #expect(info.duration > 0, "Video should have a duration")
        #expect(!info.formats.isEmpty, "Video should have formats")
    }

    // MARK: - YouTube (alternate video)

    @Test func fetchYouTubeLongVideoInfo() async throws {
        let clipService = await makeClipService()

        // Big Buck Bunny full movie on YouTube (public domain)
        let url = "https://www.youtube.com/watch?v=YE7VzlLtp-4"

        let info = try await clipService.fetchVideoInfo(url: url)

        #expect(!info.id.isEmpty, "Video should have an ID")
        #expect(!info.title.isEmpty, "Video should have a title")
        #expect(info.duration > 0, "Video should have a duration")
        #expect(!info.formats.isEmpty, "Video should have formats")
    }

    // MARK: - Format Validation

    @Test func youTubeFormatsHaveExpectedProperties() async throws {
        let clipService = await makeClipService()

        let url = "https://www.youtube.com/watch?v=aqz-KE-bpKQ"

        let info = try await clipService.fetchVideoInfo(url: url)
        let displayFormats = info.displayFormats

        #expect(displayFormats.count > 0, "Should have display formats")

        // Check that formats have expected properties
        for format in displayFormats {
            #expect(format.hasVideo, "Display formats should have video")
            #expect(format.height != nil, "Display formats should have height")
            #expect(format.height! > 0, "Height should be positive")
        }

        // YouTube typically offers multiple resolutions
        let heights = Set(displayFormats.compactMap { $0.height })
        #expect(heights.count >= 2, "YouTube should offer multiple resolutions")
    }
}
