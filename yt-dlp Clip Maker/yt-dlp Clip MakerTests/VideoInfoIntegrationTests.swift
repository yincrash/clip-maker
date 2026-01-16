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

    /// Whether we're running in a CI environment (GitHub Actions sets CI=true)
    private var isRunningInCI: Bool {
        ProcessInfo.processInfo.environment["CI"] == "true"
    }

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
    // Note: YouTube tests are skipped in CI because YouTube requires login from GitHub runners

    @Test func fetchYouTubeVideoInfo() async throws {
        // Skip in CI - YouTube requires login from GitHub runners
        if isRunningInCI {
            print("Skipping YouTube test in CI environment")
            return
        }

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
        // Skip in CI - YouTube requires login from GitHub runners
        if isRunningInCI {
            print("Skipping YouTube test in CI environment")
            return
        }

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
        // Skip in CI - YouTube requires login from GitHub runners
        if isRunningInCI {
            print("Skipping YouTube test in CI environment")
            return
        }

        let clipService = await makeClipService()

        // Big Buck Bunny full movie on YouTube (public domain)
        let url = "https://www.youtube.com/watch?v=YE7VzlLtp-4"

        let info = try await clipService.fetchVideoInfo(url: url)

        #expect(!info.id.isEmpty, "Video should have an ID")
        #expect(!info.title.isEmpty, "Video should have a title")
        #expect(info.duration > 0, "Video should have a duration")
        #expect(!info.formats.isEmpty, "Video should have formats")
    }

    // MARK: - Internet Archive

    @Test func fetchInternetArchiveVideoInfo() async throws {
        let clipService = await makeClipService()

        // Big Buck Bunny on Internet Archive (public domain, very stable)
        let url = "https://archive.org/details/BigBuckBunny_124"

        let info = try await clipService.fetchVideoInfo(url: url)

        #expect(!info.id.isEmpty, "Video should have an ID")
        #expect(!info.title.isEmpty, "Video should have a title")
        #expect(info.duration > 0, "Video should have a duration")
        #expect(!info.formats.isEmpty, "Video should have formats")

        // Check that at least one format has a recognized codec
        let hasKnownCodec = info.formats.contains { $0.codec == .h264 }
        #expect(hasKnownCodec, "Internet Archive should have at least one H.264 format")
    }

    // MARK: - Vimeo

    @Test func fetchVimeoVideoInfo() async throws {
        // Get Vimeo credentials from environment variables
        // Set these in your scheme or via: VIMEO_TEST_USERNAME=... VIMEO_TEST_PASSWORD=... xcodebuild test
        guard let username = ProcessInfo.processInfo.environment["VIMEO_TEST_USERNAME"],
              let password = ProcessInfo.processInfo.environment["VIMEO_TEST_PASSWORD"],
              !username.isEmpty, !password.isEmpty else {
            // Skip test if credentials not configured
            print("Skipping Vimeo test: VIMEO_TEST_USERNAME and VIMEO_TEST_PASSWORD environment variables not set")
            return
        }

        let clipService = await makeClipService()

        // A public Vimeo video that requires auth for yt-dlp
        let url = "https://vimeo.com/148751763"

        let info = try await clipService.fetchVideoInfo(url: url, username: username, password: password)

        #expect(!info.id.isEmpty, "Video should have an ID")
        #expect(!info.title.isEmpty, "Video should have a title")
        #expect(info.duration > 0, "Video should have a duration")
        #expect(!info.formats.isEmpty, "Video should have formats")
        #expect(info.displayFormats.count > 0, "Video should have display formats")
    }

    // MARK: - Format Validation

    @Test func youTubeFormatsHaveExpectedProperties() async throws {
        // Skip in CI - YouTube requires login from GitHub runners
        if isRunningInCI {
            print("Skipping YouTube test in CI environment")
            return
        }

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
