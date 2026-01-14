import Foundation
import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers

/// Main view model for the clip creation workflow
@MainActor
class ClipViewModel: ObservableObject {
    // MARK: - Dependencies
    private let clipService: ClipService
    private var clipTask: Task<Void, Never>?

    // MARK: - Input state
    @Published var urlInput: String = ""
    @Published var startTimeInput: String = "00:00:00"
    @Published var endTimeInput: String = "00:00:00"
    @Published var selectedFormat: VideoFormat?
    @Published var outputURL: URL?

    // MARK: - Video info state
    @Published var videoInfo: VideoInfo?
    @Published var isLoadingFormats: Bool = false
    @Published var loadError: String?

    // MARK: - Progress state
    @Published var isProcessing: Bool = false
    @Published var progress: Double = 0
    @Published var progressMessage: String = ""

    // MARK: - Console output
    @Published var consoleOutput: String = ""
    @Published var isConsoleExpanded: Bool = true

    // MARK: - Re-encoding option
    @Published var reencodeToH264: Bool = true

    // MARK: - Computed properties

    /// Whether the selected format needs re-encoding
    var formatNeedsReencode: Bool {
        selectedFormat?.needsReencode ?? false
    }

    /// Parsed start time
    var startTime: TimeInterval? {
        TimeFormatter.parse(startTimeInput)
    }

    /// Parsed end time
    var endTime: TimeInterval? {
        TimeFormatter.parse(endTimeInput)
    }

    /// Whether all inputs are valid for creating a clip
    var canStartClip: Bool {
        guard videoInfo != nil,
              selectedFormat != nil,
              let start = startTime,
              let end = endTime,
              outputURL != nil,
              !isProcessing else {
            return false
        }
        return start < end && start >= 0
    }

    /// Validation message for time inputs
    var timeValidationMessage: String? {
        guard let start = startTime, let end = endTime else {
            return "Enter valid times in HH:MM:SS format"
        }

        if start >= end {
            return "Start time must be before end time"
        }

        if let duration = videoInfo?.duration, end > duration {
            return "End time exceeds video duration"
        }

        return nil
    }

    // MARK: - Initialization

    init(clipService: ClipService) {
        self.clipService = clipService
    }

    // MARK: - Actions

    /// Load video formats from the URL
    func loadFormats() async {
        guard !urlInput.isEmpty else {
            loadError = "Please enter a URL"
            return
        }

        // Validate URL before sending to yt-dlp
        if let validationError = validateURL(urlInput) {
            loadError = validationError
            return
        }

        isLoadingFormats = true
        loadError = nil
        videoInfo = nil
        selectedFormat = nil
        consoleOutput = ""

        do {
            let info = try await clipService.fetchVideoInfo(url: urlInput)
            videoInfo = info

            // Auto-select best format, preferring h264
            if let bestH264 = info.bestH264Format {
                selectedFormat = bestH264
                reencodeToH264 = false  // No need to re-encode
            } else if let best = info.bestFormat {
                selectedFormat = best
                reencodeToH264 = true  // Default to re-encoding non-h264
            }

            // Set end time to video duration
            endTimeInput = TimeFormatter.format(info.duration)

        } catch {
            loadError = error.localizedDescription
        }

        isLoadingFormats = false
    }

    /// Show save panel and set output URL
    func selectOutputFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = sanitizeFilename(videoInfo?.title ?? "clip") + ".mp4"

        if let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            panel.directoryURL = downloadsURL
        }

        if panel.runModal() == .OK {
            outputURL = panel.url
        }
    }

    /// Start creating the clip
    func startClip() {
        guard canStartClip,
              let format = selectedFormat,
              let start = startTime,
              let end = endTime,
              let output = outputURL else {
            return
        }

        let request = ClipRequest(
            url: urlInput,
            formatId: format.id,
            startTime: start,
            endTime: end,
            outputURL: output,
            reencode: formatNeedsReencode && reencodeToH264
        )

        isProcessing = true
        progress = 0
        progressMessage = "Starting..."
        consoleOutput = ""

        clipTask = Task {
            do {
                _ = try await clipService.createClip(request: request) { [weak self] line in
                    Task { @MainActor in
                        self?.appendConsoleOutput(line)
                        self?.parseProgress(from: line)
                    }
                }

                progress = 1.0
                progressMessage = "Complete!"

                // Show the file in Finder
                NSWorkspace.shared.activateFileViewerSelecting([output])

            } catch {
                progressMessage = "Failed: \(error.localizedDescription)"
            }

            isProcessing = false
        }
    }

    /// Cancel the current clip operation
    func cancelClip() {
        clipTask?.cancel()
        clipTask = nil

        Task {
            await clipService.cancel()
        }

        isProcessing = false
        progressMessage = "Cancelled"
    }

    /// Clear console output
    func clearConsole() {
        consoleOutput = ""
    }

    /// Reset all state for a new clip
    func reset() {
        urlInput = ""
        startTimeInput = "00:00:00"
        endTimeInput = "00:00:00"
        selectedFormat = nil
        outputURL = nil
        videoInfo = nil
        loadError = nil
        progress = 0
        progressMessage = ""
        consoleOutput = ""
    }

    // MARK: - Private helpers

    private func appendConsoleOutput(_ line: String) {
        if consoleOutput.isEmpty {
            consoleOutput = line
        } else {
            consoleOutput += "\n" + line
        }
    }

    private func parseProgress(from line: String) {
        // Parse yt-dlp download progress
        // Example: [download]  45.2% of 125.3MiB at 2.5MiB/s ETA 00:32
        if line.contains("[download]") && line.contains("%") {
            if let percentRange = line.range(of: #"\d+\.?\d*%"#, options: .regularExpression) {
                let percentStr = String(line[percentRange]).replacingOccurrences(of: "%", with: "")
                if let percent = Double(percentStr) {
                    progress = percent / 100.0 * 0.8  // Download is ~80% of work
                    progressMessage = "Downloading... \(Int(percent))%"
                }
            }
        }

        // Parse ffmpeg encoding progress
        // Example: frame= 1024 fps=30 q=28.0 size=   15360kB time=00:00:34
        if line.contains("frame=") && line.contains("time=") {
            progressMessage = "Processing video..."
            progress = max(progress, 0.85)  // Encoding starts around 85%
        }

        // Merging
        if line.contains("[Merger]") || line.contains("[ffmpeg] Merging") {
            progressMessage = "Merging audio and video..."
            progress = 0.95
        }
    }

    private func sanitizeFilename(_ name: String) -> String {
        // Remove characters that aren't safe for filenames
        let invalidChars = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return name.components(separatedBy: invalidChars).joined(separator: "_")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Validate URL input to protect against yt-dlp exploitation
    /// Returns an error message if invalid, nil if valid
    private func validateURL(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for empty input
        guard !trimmed.isEmpty else {
            return "Please enter a URL"
        }

        // Reject shell metacharacters that could enable command injection
        // These characters have special meaning in shells and could be dangerous
        // Note: & is allowed since it's common in URL query strings and we use
        // Process with argument arrays (not shell execution), so it's safe
        let dangerousChars = CharacterSet(charactersIn: ";|$`\\!(){}<>'\"\n\r")
        if trimmed.rangeOfCharacter(from: dangerousChars) != nil {
            return "URL contains invalid characters"
        }

        // Must be a valid URL
        guard let url = URL(string: trimmed) else {
            return "Invalid URL format"
        }

        // Must have http or https scheme
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return "URL must start with http:// or https://"
        }

        // Must have a host
        guard let host = url.host, !host.isEmpty else {
            return "URL must include a domain"
        }

        // Reject localhost and local IP addresses
        let lowercaseHost = host.lowercased()
        if lowercaseHost == "localhost" ||
           lowercaseHost.hasPrefix("127.") ||
           lowercaseHost == "::1" ||
           lowercaseHost.hasPrefix("192.168.") ||
           lowercaseHost.hasPrefix("10.") ||
           lowercaseHost.hasPrefix("172.16.") {
            return "Local URLs are not supported"
        }

        // URL appears valid
        return nil
    }
}
