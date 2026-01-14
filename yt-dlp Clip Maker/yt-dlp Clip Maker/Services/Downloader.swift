import Foundation

/// A delegate-based downloader that reports progress updates
final class Downloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private var session: URLSession!
    private var continuation: CheckedContinuation<URL, Error>?
    private var progressHandler: ((Double) -> Void)?
    private let destinationDirectory: URL

    init(destinationDirectory: URL = FileManager.default.temporaryDirectory) {
        self.destinationDirectory = destinationDirectory
        super.init()

        let config = URLSessionConfiguration.default
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    /// Download a file from a URL with progress reporting
    /// - Parameters:
    ///   - url: The URL to download from
    ///   - onProgress: Called on the main thread with progress (0.0 to 1.0)
    /// - Returns: The local file URL where the download was saved
    func download(from url: URL, onProgress: @escaping @MainActor (Double) -> Void) async throws -> URL {
        self.progressHandler = { progress in
            Task { @MainActor in
                onProgress(progress)
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let task = session.downloadTask(with: url)
            task.resume()
        }
    }

    // MARK: - URLSessionDownloadDelegate

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Move file from temporary location to our destination
        let fileName = downloadTask.originalRequest?.url?.lastPathComponent ?? UUID().uuidString
        let destinationURL = destinationDirectory.appendingPathComponent(fileName)

        do {
            // Remove existing file if present
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            // Copy instead of move since the temp file may be deleted
            try FileManager.default.copyItem(at: location, to: destinationURL)

            continuation?.resume(returning: destinationURL)
            continuation = nil
        } catch {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }

        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        progressHandler?(progress)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}
