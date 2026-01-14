import Foundation

/// Service for interacting with yt-dlp to fetch video info and create clips
class ClipService {
    private let processRunner = ProcessRunner()
    private let dependencyManager: DependencyManager

    init(dependencyManager: DependencyManager) {
        self.dependencyManager = dependencyManager
    }

    /// Fetch video information and available formats from a URL
    func fetchVideoInfo(url: String) async throws -> VideoInfo {
        let ytDlpPath = dependencyManager.ytDlpPath

        let overallStart = CFAbsoluteTimeGetCurrent()
        debugLog("Starting fetchVideoInfo for URL: \(url)", since: overallStart)
        debugLog("Using yt-dlp at: \(ytDlpPath.path)", since: overallStart)

        let result = try await processRunner.runAndCapture(
            executable: ytDlpPath,
            arguments: ["-J", "--no-warnings", url]
        )
        debugLog("yt-dlp process completed", since: overallStart)
        debugLog("Exit code: \(result.exitCode)", since: overallStart)
        debugLog("stdout length: \(result.stdout.count) chars", since: overallStart)
        debugLog("stderr: \(result.stderr.isEmpty ? "(empty)" : result.stderr)", since: overallStart)

        guard result.exitCode == 0 else {
            let errorMessage = result.stderr.isEmpty ? "Unknown error" : result.stderr
            throw ClipServiceError.fetchFailed(errorMessage)
        }

        guard let jsonData = result.stdout.data(using: .utf8) else {
            throw ClipServiceError.parseFailed("Invalid response data")
        }

        let info = try parseVideoInfo(from: jsonData)
        debugLog("JSON parsing completed, found \(info.formats.count) formats", since: overallStart)

        debugLog("fetchVideoInfo complete", since: overallStart)

        return info
    }

    private func debugLog(_ message: String, since start: CFAbsoluteTime) {
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        print(String(format: "[DEBUG +%.2fs] %@", elapsed, message))
    }

    /// Create a clip from a video
    /// - Returns: AsyncStream of progress updates and console output
    func createClip(
        request: ClipRequest,
        onOutput: @escaping @Sendable (String) -> Void
    ) async throws -> URL {
        let ytDlpPath = dependencyManager.ytDlpPath
        let ffmpegPath = dependencyManager.ffmpegPath

        var arguments = [
            "--ffmpeg-location", ffmpegPath.deletingLastPathComponent().path,
            "--external-downloader", ffmpegPath.path,
            "--external-downloader-args", "ffmpeg_i:-ss \(request.formattedStartTime) -to \(request.formattedEndTime)",
            "-f", "\(request.formatId)+bestaudio/\(request.formatId)",
            "--merge-output-format", "mp4",
            "--newline",  // Output progress on new lines
            "-o", request.outputURL.path,
            request.url
        ]

        // Add re-encoding arguments if needed
        if request.reencode {
            arguments.insert(contentsOf: [
                "--postprocessor-args",
                "ffmpeg:-c:v libx264 -preset medium -crf 23 -c:a aac"
            ], at: arguments.count - 1)
        }

        // Log the command being run
        let command = ProcessRunner.formatCommand(executable: ytDlpPath, arguments: arguments)
        onOutput(command)
        onOutput("")

        let exitCode = try await processRunner.run(
            executable: ytDlpPath,
            arguments: arguments,
            onOutput: onOutput
        )

        guard exitCode == 0 else {
            throw ClipServiceError.clipFailed("Process exited with code \(exitCode)")
        }

        // Verify the file was created
        guard FileManager.default.fileExists(atPath: request.outputURL.path) else {
            throw ClipServiceError.clipFailed("Output file was not created")
        }

        return request.outputURL
    }

    /// Build the command string for display (without executing)
    func buildCommandString(for request: ClipRequest) -> String {
        let ytDlpPath = dependencyManager.ytDlpPath
        let ffmpegPath = dependencyManager.ffmpegPath

        var arguments = [
            "--ffmpeg-location", ffmpegPath.deletingLastPathComponent().path,
            "--external-downloader", ffmpegPath.path,
            "--external-downloader-args", "ffmpeg_i:-ss \(request.formattedStartTime) -to \(request.formattedEndTime)",
            "-f", "\(request.formatId)+bestaudio/\(request.formatId)",
            "--merge-output-format", "mp4",
            "-o", request.outputURL.path,
            request.url
        ]

        if request.reencode {
            arguments.insert(contentsOf: [
                "--postprocessor-args",
                "ffmpeg:-c:v libx264 -preset medium -crf 23 -c:a aac"
            ], at: arguments.count - 1)
        }

        return ProcessRunner.formatCommand(executable: ytDlpPath, arguments: arguments)
    }

    /// Cancel any running operation
    func cancel() async {
        await processRunner.cancel()
    }

    // MARK: - Private parsing

    private func parseVideoInfo(from jsonData: Data) throws -> VideoInfo {
        guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw ClipServiceError.parseFailed("Invalid JSON structure")
        }

        let id = json["id"] as? String ?? ""
        let title = json["title"] as? String ?? "Unknown Title"
        let duration = json["duration"] as? Double ?? 0
        let thumbnail = (json["thumbnail"] as? String).flatMap { URL(string: $0) }

        // Parse formats
        var formats: [VideoFormat] = []
        if let formatList = json["formats"] as? [[String: Any]] {
            for formatJson in formatList {
                if let format = parseFormat(from: formatJson) {
                    formats.append(format)
                }
            }
        }

        return VideoInfo(
            id: id,
            title: title,
            duration: duration,
            thumbnailURL: thumbnail,
            formats: formats
        )
    }

    private func parseFormat(from json: [String: Any]) -> VideoFormat? {
        guard let formatId = json["format_id"] as? String else {
            return nil
        }

        let vcodec = json["vcodec"] as? String
        let hasVideo = vcodec != nil && vcodec != "none"

        // Skip audio-only formats for our purposes
        guard hasVideo else {
            return nil
        }

        // Skip HLS/m3u8 formats - they don't support time range downloads
        // The external downloader approach only works with seekable HTTPS streams
        let proto = json["protocol"] as? String ?? ""
        if proto.contains("m3u8") || proto.contains("hls") {
            return nil
        }

        let acodec = json["acodec"] as? String
        let hasAudio = acodec != nil && acodec != "none"

        return VideoFormat(
            id: formatId,
            formatNote: json["format_note"] as? String,
            width: json["width"] as? Int,
            height: json["height"] as? Int,
            fps: json["fps"] as? Int,
            codec: VideoCodec(from: vcodec),
            videoBitrate: (json["vbr"] as? Double).map { Int($0) },
            filesize: json["filesize"] as? Int ?? json["filesize_approx"] as? Int,
            hasVideo: hasVideo,
            hasAudio: hasAudio,
            audioCodec: acodec
        )
    }
}

enum ClipServiceError: LocalizedError {
    case fetchFailed(String)
    case parseFailed(String)
    case clipFailed(String)

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let message):
            return "Failed to fetch video info: \(message)"
        case .parseFailed(let message):
            return "Failed to parse video info: \(message)"
        case .clipFailed(let message):
            return "Failed to create clip: \(message)"
        }
    }
}
