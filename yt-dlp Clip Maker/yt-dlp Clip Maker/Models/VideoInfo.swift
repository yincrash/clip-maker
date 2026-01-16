import Foundation

/// Information about a video fetched from yt-dlp
struct VideoInfo {
    let id: String
    let title: String
    let duration: TimeInterval
    let thumbnailURL: URL?
    let formats: [VideoFormat]

    /// Get formats suitable for display (video+audio combined, sorted by quality)
    var displayFormats: [VideoFormat] {
        // Filter to formats that have video and can be merged with audio
        let videoFormats = formats.filter { $0.hasVideo && $0.height != nil }

        // Group by resolution and pick best codec for each
        var byResolution: [Int: VideoFormat] = [:]
        for format in videoFormats {
            guard let height = format.height else { continue }
            if let existing = byResolution[height] {
                // Prefer h264, then by bitrate
                if format.codec == .h264 && existing.codec != .h264 {
                    byResolution[height] = format
                } else if format.codec == existing.codec,
                          let newBitrate = format.videoBitrate,
                          let existingBitrate = existing.videoBitrate,
                          newBitrate > existingBitrate {
                    byResolution[height] = format
                }
            } else {
                byResolution[height] = format
            }
        }

        return byResolution.values.sorted { ($0.height ?? 0) > ($1.height ?? 0) }
    }

    /// Best format by resolution
    var bestFormat: VideoFormat? {
        displayFormats.first
    }

    /// Best h264 format (no re-encoding needed)
    var bestH264Format: VideoFormat? {
        displayFormats.first { $0.codec == .h264 }
    }

    /// Format duration as HH:MM:SS
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

/// A specific format/quality option for a video
struct VideoFormat: Identifiable, Equatable, Hashable {
    let id: String              // format ID from yt-dlp
    let formatNote: String?     // e.g., "1080p", "720p60"
    let width: Int?
    let height: Int?
    let fps: Int?
    let codec: VideoCodec
    let videoBitrate: Int?      // in kbps
    let filesize: Int?          // estimated in bytes
    let hasVideo: Bool
    let hasAudio: Bool
    let audioCodec: String?

    /// User-friendly display label
    var displayLabel: String {
        var label = ""

        if let height = height {
            label = "\(height)p"
            if let fps = fps, fps > 30 {
                label += "\(fps)"
            }
        } else if let note = formatNote {
            label = note
        } else {
            label = id
        }

        return label
    }

    /// More detailed label including codec
    var detailedLabel: String {
        var label = displayLabel
        label += " (\(codec.displayName))"
        return label
    }

    /// Whether this format needs re-encoding for broad compatibility
    var needsReencode: Bool {
        codec.requiresReencode
    }

    static func == (lhs: VideoFormat, rhs: VideoFormat) -> Bool {
        lhs.id == rhs.id
    }
}

/// Video codec types
enum VideoCodec: String, CaseIterable {
    case h264 = "avc1"
    case h265 = "hev1"
    case vp9 = "vp9"
    case vp8 = "vp8"
    case av1 = "av01"
    case unknown

    /// User-friendly codec name
    var displayName: String {
        switch self {
        case .h264: return "H.264"
        case .h265: return "H.265"
        case .vp9: return "VP9"
        case .vp8: return "VP8"
        case .av1: return "AV1"
        case .unknown: return "Unknown"
        }
    }

    /// Whether this codec requires re-encoding for maximum compatibility
    var requiresReencode: Bool {
        self != .h264
    }

    /// Initialize from yt-dlp vcodec string, with optional format string fallback
    /// The formatString is used for sources like Internet Archive that don't provide vcodec
    init(from vcodec: String?, formatString: String? = nil) {
        // Try vcodec first
        if let vcodec = vcodec?.lowercased(), vcodec != "none" {
            if vcodec.contains("avc") || vcodec.contains("h264") {
                self = .h264
                return
            } else if vcodec.contains("hev") || vcodec.contains("h265") || vcodec.contains("hevc") {
                self = .h265
                return
            } else if vcodec.contains("vp9") || vcodec.contains("vp09") {
                self = .vp9
                return
            } else if vcodec.contains("vp8") {
                self = .vp8
                return
            } else if vcodec.contains("av01") || vcodec.contains("av1") {
                self = .av1
                return
            }
        }

        // Fall back to format string (e.g., "h.264" from Internet Archive)
        if let format = formatString?.lowercased() {
            if format.contains("h.264") || format.contains("h264") || format.contains("avc") {
                self = .h264
                return
            } else if format.contains("h.265") || format.contains("h265") || format.contains("hevc") {
                self = .h265
                return
            } else if format.contains("vp9") {
                self = .vp9
                return
            } else if format.contains("vp8") {
                self = .vp8
                return
            } else if format.contains("av1") {
                self = .av1
                return
            }
        }

        self = .unknown
    }
}
