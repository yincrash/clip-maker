import Foundation
import SwiftUI
import Combine

/// Information about a dependency for display in UI
struct DependencyInfo {
    let name: String
    let description: String
    let learnMoreURL: URL
    let downloadURL: URL

    static let ytDlp = DependencyInfo(
        name: "yt-dlp",
        description: "Fetches videos from YouTube and other websites.",
        learnMoreURL: URL(string: "https://github.com/yt-dlp/yt-dlp")!,
        downloadURL: URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos")!
    )

    static let ffmpeg = DependencyInfo(
        name: "FFmpeg",
        description: "Trims and converts video files.",
        learnMoreURL: URL(string: "https://ffmpeg.org")!,
        downloadURL: URL(string: "https://evermeet.cx/ffmpeg/getrelease/zip")!
    )
}

/// Source of a dependency installation
enum DependencySource: Equatable {
    case appBundle      // Downloaded by this app to Application Support
    case systemPath     // Found in user's PATH (e.g., /usr/local/bin)

    var displayName: String {
        switch self {
        case .appBundle: return "App"
        case .systemPath: return "System"
        }
    }
}

/// Status of a dependency
enum DependencyStatus: Equatable {
    case notInstalled
    case checking
    case downloading(progress: Double)
    case installed(version: String, source: DependencySource)
    case foundInPath(path: String, version: String)  // Found but not yet chosen
    case error(String)

    var isReady: Bool {
        if case .installed = self {
            return true
        }
        return false
    }

    var version: String? {
        switch self {
        case .installed(let version, _):
            return version
        case .foundInPath(_, let version):
            return version
        default:
            return nil
        }
    }
}

/// Manages downloading and checking yt-dlp and ffmpeg binaries
@MainActor
class DependencyManager: ObservableObject {
    @Published var ytDlpStatus: DependencyStatus = .notInstalled
    @Published var ffmpegStatus: DependencyStatus = .notInstalled

    // Tracks which path to actually use (may be system or app bundle)
    @Published private(set) var activeYtDlpPath: URL?
    @Published private(set) var activeFfmpegPath: URL?

    // System paths if found
    private(set) var systemYtDlpPath: URL?
    private(set) var systemFfmpegPath: URL?

    private let fileManager: FileManager
    private let processRunner: ProcessRunner
    private let pathFinder: PathFinderProtocol = PathFinder()
    private let defaults = UserDefaults.standard

    // Cache keys
    private enum CacheKey {
        static let ytDlpVersion = "cachedYtDlpVersion"
        static let ytDlpModDate = "cachedYtDlpModDate"
        static let ytDlpPath = "cachedYtDlpPath"
        static let ffmpegVersion = "cachedFfmpegVersion"
        static let ffmpegModDate = "cachedFfmpegModDate"
        static let ffmpegPath = "cachedFfmpegPath"
    }

    // User preference keys for dependency source
    private enum PreferenceKey {
        static let ytDlpSource = "preferredYtDlpSource"  // "app" or "system"
        static let ffmpegSource = "preferredFfmpegSource"
        static let ytDlpSystemPath = "savedSystemYtDlpPath"
        static let ffmpegSystemPath = "savedSystemFfmpegPath"
    }

    init(
        fileManager: FileManager = .default,
        processRunner: ProcessRunner = ProcessRunner()
    ) {
        self.fileManager = fileManager
        self.processRunner = processRunner
    }

    /// Directory where binaries are stored
    var binDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("yt-dlp Clip Maker/bin", isDirectory: true)
    }

    /// Path to app-bundled yt-dlp binary
    var appYtDlpPath: URL {
        binDirectory.appendingPathComponent("yt-dlp")
    }

    /// Path to app-bundled ffmpeg binary
    var appFfmpegPath: URL {
        binDirectory.appendingPathComponent("ffmpeg")
    }

    /// Path to yt-dlp binary (active path for use)
    var ytDlpPath: URL {
        activeYtDlpPath ?? appYtDlpPath
    }

    /// Path to ffmpeg binary (active path for use)
    var ffmpegPath: URL {
        activeFfmpegPath ?? appFfmpegPath
    }

    /// Whether all dependencies are installed and ready
    var allDependenciesReady: Bool {
        ytDlpStatus.isReady && ffmpegStatus.isReady
    }

    /// Whether system installations were found
    var hasSystemYtDlp: Bool {
        if case .foundInPath = ytDlpStatus { return true }
        if case .installed(_, .systemPath) = ytDlpStatus { return true }
        return false
    }

    var hasSystemFfmpeg: Bool {
        if case .foundInPath = ffmpegStatus { return true }
        if case .installed(_, .systemPath) = ffmpegStatus { return true }
        return false
    }

    /// Check if dependencies are installed and get their versions
    func checkDependencies() async {
        ytDlpStatus = .checking
        ffmpegStatus = .checking

        // Load saved preferences
        let preferredYtDlpSource = defaults.string(forKey: PreferenceKey.ytDlpSource)
        let preferredFfmpegSource = defaults.string(forKey: PreferenceKey.ffmpegSource)

        // Check for system installations first (to populate systemYtDlpPath/systemFfmpegPath)
        if let systemPath = pathFinder.findBinary(named: "yt-dlp") {
            systemYtDlpPath = systemPath
        } else if let savedPath = defaults.string(forKey: PreferenceKey.ytDlpSystemPath) {
            let url = URL(fileURLWithPath: savedPath)
            if pathFinder.fileExists(at: url) {
                systemYtDlpPath = url
            }
        }

        if let systemPath = pathFinder.findBinary(named: "ffmpeg") {
            systemFfmpegPath = systemPath
        } else if let savedPath = defaults.string(forKey: PreferenceKey.ffmpegSystemPath) {
            let url = URL(fileURLWithPath: savedPath)
            if pathFinder.fileExists(at: url) {
                systemFfmpegPath = url
            }
        }

        // Check yt-dlp based on saved preference
        if preferredYtDlpSource == "system", let systemPath = systemYtDlpPath {
            // User previously chose system version
            if let version = await getVersion(for: systemPath) {
                ytDlpStatus = .installed(version: version, source: .systemPath)
                activeYtDlpPath = systemPath
            } else {
                // System version no longer works, fall back to checking others
                ytDlpStatus = .notInstalled
            }
        } else if preferredYtDlpSource == "app" || preferredYtDlpSource == nil {
            // Check app bundle first
            if pathFinder.fileExists(at: appYtDlpPath) {
                if let version = await getVersion(for: appYtDlpPath) {
                    ytDlpStatus = .installed(version: version, source: .appBundle)
                    activeYtDlpPath = appYtDlpPath
                } else {
                    ytDlpStatus = .error("Unable to get version")
                }
            } else if let systemPath = systemYtDlpPath {
                // No app bundle, but system is available
                if let version = await getVersion(for: systemPath) {
                    ytDlpStatus = .foundInPath(path: systemPath.path, version: version)
                } else {
                    ytDlpStatus = .notInstalled
                }
            } else {
                ytDlpStatus = .notInstalled
            }
        }

        // Check ffmpeg based on saved preference
        if preferredFfmpegSource == "system", let systemPath = systemFfmpegPath {
            // User previously chose system version
            if let version = await getFfmpegVersion(at: systemPath) {
                ffmpegStatus = .installed(version: version, source: .systemPath)
                activeFfmpegPath = systemPath
            } else {
                // System version no longer works, fall back to checking others
                ffmpegStatus = .notInstalled
            }
        } else if preferredFfmpegSource == "app" || preferredFfmpegSource == nil {
            // Check app bundle first
            if pathFinder.fileExists(at: appFfmpegPath) {
                if let version = await getFfmpegVersion(at: appFfmpegPath) {
                    ffmpegStatus = .installed(version: version, source: .appBundle)
                    activeFfmpegPath = appFfmpegPath
                } else {
                    ffmpegStatus = .error("Unable to get version")
                }
            } else if let systemPath = systemFfmpegPath {
                // No app bundle, but system is available
                if let version = await getFfmpegVersion(at: systemPath) {
                    ffmpegStatus = .foundInPath(path: systemPath.path, version: version)
                } else {
                    ffmpegStatus = .notInstalled
                }
            } else {
                ffmpegStatus = .notInstalled
            }
        }
    }

    /// Use the system-installed version of yt-dlp
    func useSystemYtDlp() {
        guard let systemPath = systemYtDlpPath else { return }
        activeYtDlpPath = systemPath
        defaults.set("system", forKey: PreferenceKey.ytDlpSource)
        defaults.set(systemPath.path, forKey: PreferenceKey.ytDlpSystemPath)

        // Update status to reflect the change
        Task {
            if let version = await getVersion(for: systemPath) {
                ytDlpStatus = .installed(version: version, source: .systemPath)
            }
        }
    }

    /// Use the system-installed version of ffmpeg
    func useSystemFfmpeg() {
        guard let systemPath = systemFfmpegPath else { return }
        activeFfmpegPath = systemPath
        defaults.set("system", forKey: PreferenceKey.ffmpegSource)
        defaults.set(systemPath.path, forKey: PreferenceKey.ffmpegSystemPath)

        // Update status to reflect the change
        Task {
            if let version = await getFfmpegVersion(at: systemPath) {
                ffmpegStatus = .installed(version: version, source: .systemPath)
            }
        }
    }

    /// Use the app-bundled version of yt-dlp
    func useAppYtDlp() {
        guard pathFinder.fileExists(at: appYtDlpPath) else { return }
        activeYtDlpPath = appYtDlpPath
        defaults.set("app", forKey: PreferenceKey.ytDlpSource)

        // Update status to reflect the change
        Task {
            if let version = await getVersion(for: appYtDlpPath) {
                ytDlpStatus = .installed(version: version, source: .appBundle)
            }
        }
    }

    /// Use the app-bundled version of ffmpeg
    func useAppFfmpeg() {
        guard pathFinder.fileExists(at: appFfmpegPath) else { return }
        activeFfmpegPath = appFfmpegPath
        defaults.set("app", forKey: PreferenceKey.ffmpegSource)

        // Update status to reflect the change
        Task {
            if let version = await getFfmpegVersion(at: appFfmpegPath) {
                ffmpegStatus = .installed(version: version, source: .appBundle)
            }
        }
    }

    /// Whether app-bundled yt-dlp is available
    var hasAppYtDlp: Bool {
        pathFinder.fileExists(at: appYtDlpPath)
    }

    /// Whether app-bundled ffmpeg is available
    var hasAppFfmpeg: Bool {
        pathFinder.fileExists(at: appFfmpegPath)
    }

    /// Current source for yt-dlp
    var ytDlpSource: DependencySource? {
        if case .installed(_, let source) = ytDlpStatus {
            return source
        }
        return nil
    }

    /// Current source for ffmpeg
    var ffmpegSource: DependencySource? {
        if case .installed(_, let source) = ffmpegStatus {
            return source
        }
        return nil
    }

    /// Download yt-dlp binary
    func downloadYtDlp() async throws {
        ytDlpStatus = .downloading(progress: 0)

        // Clear version cache since we're downloading a new binary
        clearVersionCache(versionKey: CacheKey.ytDlpVersion, modDateKey: CacheKey.ytDlpModDate, pathKey: CacheKey.ytDlpPath)

        // Ensure bin directory exists
        try fileManager.createDirectory(at: binDirectory, withIntermediateDirectories: true)

        // Download the binary using delegate-based downloader
        let downloader = Downloader()
        let localURL = try await downloader.download(
            from: DependencyInfo.ytDlp.downloadURL,
            onProgress: { [weak self] progress in
                self?.ytDlpStatus = .downloading(progress: progress)
            }
        )

        // Move to final location
        if fileManager.fileExists(atPath: appYtDlpPath.path) {
            try fileManager.removeItem(at: appYtDlpPath)
        }
        try fileManager.moveItem(at: localURL, to: appYtDlpPath)

        // Make executable and remove quarantine
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: appYtDlpPath.path)
        removeQuarantine(from: appYtDlpPath)

        // Verify and get version (this will cache the version)
        if let version = await getVersion(for: appYtDlpPath) {
            ytDlpStatus = .installed(version: version, source: .appBundle)
            activeYtDlpPath = appYtDlpPath
            // Save preference for app bundle
            defaults.set("app", forKey: PreferenceKey.ytDlpSource)
        } else {
            ytDlpStatus = .error("Download completed but unable to verify")
        }
    }

    /// Download ffmpeg binary
    func downloadFfmpeg() async throws {
        ffmpegStatus = .downloading(progress: 0)

        // Clear version cache since we're downloading a new binary
        clearVersionCache(versionKey: CacheKey.ffmpegVersion, modDateKey: CacheKey.ffmpegModDate, pathKey: CacheKey.ffmpegPath)

        // Ensure bin directory exists
        try fileManager.createDirectory(at: binDirectory, withIntermediateDirectories: true)

        // Download the zip file using delegate-based downloader
        let downloader = Downloader()
        let localURL = try await downloader.download(
            from: DependencyInfo.ffmpeg.downloadURL,
            onProgress: { [weak self] progress in
                self?.ffmpegStatus = .downloading(progress: progress)
            }
        )

        // Unzip the file
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let unzipProcess = Process()
        unzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzipProcess.arguments = ["-o", localURL.path, "-d", tempDir.path]
        unzipProcess.standardOutput = nil
        unzipProcess.standardError = nil
        try unzipProcess.run()
        unzipProcess.waitUntilExit()

        // Find the ffmpeg binary in the extracted contents
        let extractedContents = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        var ffmpegBinary: URL?
        for item in extractedContents {
            if item.lastPathComponent == "ffmpeg" {
                ffmpegBinary = item
                break
            }
        }

        guard let sourceBinary = ffmpegBinary else {
            throw DependencyError.extractionFailed("Could not find ffmpeg in downloaded archive")
        }

        // Move to final location
        if fileManager.fileExists(atPath: appFfmpegPath.path) {
            try fileManager.removeItem(at: appFfmpegPath)
        }
        try fileManager.moveItem(at: sourceBinary, to: appFfmpegPath)

        // Clean up
        try? fileManager.removeItem(at: localURL)
        try? fileManager.removeItem(at: tempDir)

        // Make executable and remove quarantine
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: appFfmpegPath.path)
        removeQuarantine(from: appFfmpegPath)

        // Verify and get version
        if let version = await getFfmpegVersion(at: appFfmpegPath) {
            ffmpegStatus = .installed(version: version, source: .appBundle)
            activeFfmpegPath = appFfmpegPath
            // Save preference for app bundle
            defaults.set("app", forKey: PreferenceKey.ffmpegSource)
        } else {
            ffmpegStatus = .error("Download completed but unable to verify")
        }
    }

    /// Download both dependencies
    func downloadAll() async throws {
        // Download in parallel
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await self.downloadYtDlp()
            }
            group.addTask {
                try await self.downloadFfmpeg()
            }
            try await group.waitForAll()
        }
    }

    // MARK: - Private helpers

    private func getVersion(for path: URL) async -> String? {
        let start = CFAbsoluteTimeGetCurrent()
        print("[DEBUG DependencyManager] Getting yt-dlp version from: \(path.path)")

        // Check cache first
        if let cached = getCachedVersion(for: path, versionKey: CacheKey.ytDlpVersion, modDateKey: CacheKey.ytDlpModDate, pathKey: CacheKey.ytDlpPath) {
            print("[DEBUG DependencyManager] Using cached yt-dlp version: \(cached) (0.00s)")
            return cached
        }

        do {
            let result = try await processRunner.runAndCapture(
                executable: path,
                arguments: ["--version", "--no-update-check"]
            )
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            print("[DEBUG DependencyManager] yt-dlp --version completed in \(String(format: "%.2f", elapsed))s")
            if result.exitCode == 0 {
                let version = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                cacheVersion(version, for: path, versionKey: CacheKey.ytDlpVersion, modDateKey: CacheKey.ytDlpModDate, pathKey: CacheKey.ytDlpPath)
                return version
            }
        } catch {
            // Silently fail - version check is not critical
            print("[DEBUG DependencyManager] yt-dlp --version failed: \(error)")
        }
        return nil
    }

    private func getFfmpegVersion(at path: URL) async -> String? {
        let start = CFAbsoluteTimeGetCurrent()
        print("[DEBUG DependencyManager] Getting ffmpeg version from: \(path.path)")

        // Check cache first
        if let cached = getCachedVersion(for: path, versionKey: CacheKey.ffmpegVersion, modDateKey: CacheKey.ffmpegModDate, pathKey: CacheKey.ffmpegPath) {
            print("[DEBUG DependencyManager] Using cached ffmpeg version: \(cached) (0.00s)")
            return cached
        }

        do {
            let result = try await processRunner.runAndCapture(
                executable: path,
                arguments: ["-version"]
            )
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            print("[DEBUG DependencyManager] ffmpeg -version completed in \(String(format: "%.2f", elapsed))s")
            if result.exitCode == 0 {
                // Parse first line for version
                let firstLine = result.stdout.components(separatedBy: .newlines).first ?? ""
                // ffmpeg version 6.1 Copyright...
                var version = "installed"
                if let versionMatch = firstLine.range(of: #"ffmpeg version ([^\s]+)"#, options: .regularExpression) {
                    let versionPart = String(firstLine[versionMatch])
                    version = versionPart.replacingOccurrences(of: "ffmpeg version ", with: "")
                }
                cacheVersion(version, for: path, versionKey: CacheKey.ffmpegVersion, modDateKey: CacheKey.ffmpegModDate, pathKey: CacheKey.ffmpegPath)
                return version
            }
        } catch {
            // Silently fail - version check is not critical
            print("[DEBUG DependencyManager] ffmpeg -version failed: \(error)")
        }
        return nil
    }

    /// Remove macOS quarantine attribute from downloaded binary
    private func removeQuarantine(from url: URL) {
        // Use removexattr directly instead of spawning xattr process
        let _ = removexattr(url.path, "com.apple.quarantine", 0)
        // Ignore errors - ENOATTR just means no quarantine attribute exists
    }

    // MARK: - Version caching

    /// Get cached version if the file hasn't changed
    private func getCachedVersion(for path: URL, versionKey: String, modDateKey: String, pathKey: String) -> String? {
        guard let cachedVersion = defaults.string(forKey: versionKey),
              let cachedPath = defaults.string(forKey: pathKey),
              cachedPath == path.path,
              let cachedModDate = defaults.object(forKey: modDateKey) as? Date else {
            return nil
        }

        // Check if file modification date matches
        guard let currentModDate = getFileModificationDate(for: path),
              currentModDate == cachedModDate else {
            return nil
        }

        return cachedVersion
    }

    /// Cache a version for a binary
    private func cacheVersion(_ version: String, for path: URL, versionKey: String, modDateKey: String, pathKey: String) {
        defaults.set(version, forKey: versionKey)
        defaults.set(path.path, forKey: pathKey)
        if let modDate = getFileModificationDate(for: path) {
            defaults.set(modDate, forKey: modDateKey)
        }
    }

    /// Clear cached version (call after downloading new binary)
    private func clearVersionCache(versionKey: String, modDateKey: String, pathKey: String) {
        defaults.removeObject(forKey: versionKey)
        defaults.removeObject(forKey: modDateKey)
        defaults.removeObject(forKey: pathKey)
    }

    /// Get file modification date
    private func getFileModificationDate(for path: URL) -> Date? {
        try? fileManager.attributesOfItem(atPath: path.path)[.modificationDate] as? Date
    }
}

enum DependencyError: LocalizedError {
    case downloadFailed(String)
    case extractionFailed(String)
    case verificationFailed(String)

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .extractionFailed(let message):
            return "Extraction failed: \(message)"
        case .verificationFailed(let message):
            return "Verification failed: \(message)"
        }
    }
}
