import Foundation

/// Request parameters for creating a video clip
struct ClipRequest {
    let url: String
    let formatId: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let outputURL: URL
    let reencode: Bool

    /// Duration of the clip in seconds
    var duration: TimeInterval {
        endTime - startTime
    }

    /// Start time formatted as HH:MM:SS
    var formattedStartTime: String {
        formatTime(startTime)
    }

    /// End time formatted as HH:MM:SS
    var formattedEndTime: String {
        formatTime(endTime)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

/// Progress updates during clip creation
enum ClipProgress: Equatable {
    case started
    case downloading(percent: Double, message: String)
    case processing(percent: Double, message: String)
    case merging(message: String)
    case completed(outputURL: URL)
    case failed(error: String)

    var isComplete: Bool {
        switch self {
        case .completed, .failed:
            return true
        default:
            return false
        }
    }

    var percent: Double {
        switch self {
        case .started:
            return 0
        case .downloading(let percent, _):
            return percent * 0.8  // Download is 80% of work
        case .processing(let percent, _):
            return 0.8 + (percent * 0.15)  // Processing is 15%
        case .merging:
            return 0.95
        case .completed:
            return 1.0
        case .failed:
            return 0
        }
    }

    var message: String {
        switch self {
        case .started:
            return "Starting..."
        case .downloading(_, let message):
            return message
        case .processing(_, let message):
            return message
        case .merging(let message):
            return message
        case .completed:
            return "Complete!"
        case .failed(let error):
            return "Failed: \(error)"
        }
    }
}
