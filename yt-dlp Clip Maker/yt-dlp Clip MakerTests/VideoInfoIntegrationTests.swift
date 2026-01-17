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
    // Note: YouTube tests are disabled in CI because YouTube requires login from GitHub runners
    // The CI flag is set via SWIFT_ACTIVE_COMPILATION_CONDITIONS in the CI workflow

#if !CI
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
#endif

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

    /// Reads Vimeo credentials from DeveloperSettings.xcconfig file
    private func getVimeoCredentials() -> (username: String, password: String)? {
        let projectDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Tests dir
            .deletingLastPathComponent()  // yt-dlp Clip MakerTests
        let xcconfigPath = projectDir.appendingPathComponent("DeveloperSettings.xcconfig")

        guard let contents = try? String(contentsOf: xcconfigPath, encoding: .utf8) else {
            return nil
        }

        var username: String?
        var password: String?

        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("VIMEO_TEST_USERNAME") {
                username = trimmed.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("VIMEO_TEST_PASSWORD") {
                password = trimmed.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces)
            }
        }

        if let u = username, let p = password, !u.isEmpty, !p.isEmpty {
            return (u, p)
        }
        return nil
    }

    @Test func fetchVimeoVideoInfo() async throws {
        // Get Vimeo credentials from DeveloperSettings.xcconfig
        guard let credentials = getVimeoCredentials() else {
            #expect(Bool(false), "VIMEO_TEST_USERNAME and VIMEO_TEST_PASSWORD must be set in DeveloperSettings.xcconfig")
            return
        }

        let username = credentials.username
        let password = credentials.password

        let clipService = await makeClipService()

        // Big Buck Bunny on Vimeo (public domain, stable)
        let url = "https://vimeo.com/1084537"

        let info = try await clipService.fetchVideoInfo(url: url, username: username, password: password)

        #expect(!info.id.isEmpty, "Video should have an ID")
        #expect(!info.title.isEmpty, "Video should have a title")
        #expect(info.duration > 0, "Video should have a duration")
        #expect(!info.formats.isEmpty, "Video should have formats")
        #expect(info.displayFormats.count > 0, "Video should have display formats")
    }
}
