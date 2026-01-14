import Foundation

/// Executes shell commands and streams output
actor ProcessRunner {
    private var currentProcess: Process?
    private var isCancelled = false

    /// Run an executable with arguments, streaming output line by line
    /// - Parameters:
    ///   - executable: Path to the executable
    ///   - arguments: Command line arguments
    ///   - onOutput: Callback for each line of output (stdout and stderr combined)
    /// - Returns: Exit code of the process
    func run(
        executable: URL,
        arguments: [String],
        onOutput: @escaping @Sendable (String) -> Void
    ) async throws -> Int32 {
        isCancelled = false

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        currentProcess = process

        // Set up async reading of output
        let outputHandle = pipe.fileHandleForReading

        return try await withCheckedThrowingContinuation { continuation in
            // Read output in background
            Task.detached {
                while true {
                    let data = outputHandle.availableData
                    if data.isEmpty {
                        break
                    }
                    if let output = String(data: data, encoding: .utf8) {
                        // Split by lines and call callback for each
                        let lines = output.components(separatedBy: .newlines)
                        for line in lines where !line.isEmpty {
                            onOutput(line)
                        }
                    }
                }
            }

            process.terminationHandler = { process in
                continuation.resume(returning: process.terminationStatus)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Run a command and capture all output at once
    /// - Parameters:
    ///   - executable: Path to the executable
    ///   - arguments: Command line arguments
    /// - Returns: Tuple of (exitCode, stdout, stderr)
    func runAndCapture(
        executable: URL,
        arguments: [String]
    ) async throws -> (exitCode: Int32, stdout: String, stderr: String) {
        let start = CFAbsoluteTimeGetCurrent()

        func debugLog(_ message: String) {
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            print(String(format: "[DEBUG ProcessRunner +%.2fs] %@", elapsed, message))
        }

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        currentProcess = process

        debugLog("Process setup complete")

        // Read pipe data asynchronously to avoid buffer deadlock
        // When output exceeds pipe buffer size (~64KB), the process blocks
        // unless we're actively reading from the pipes
        var stdoutData = Data()
        var stderrData = Data()

        let stdoutHandle = stdoutPipe.fileHandleForReading
        let stderrHandle = stderrPipe.fileHandleForReading

        // Start reading stdout in background
        let stdoutTask = Task.detached { () -> Data in
            var data = Data()
            while true {
                let chunk = stdoutHandle.availableData
                if chunk.isEmpty { break }
                data.append(chunk)
            }
            return data
        }

        // Start reading stderr in background
        let stderrTask = Task.detached { () -> Data in
            var data = Data()
            while true {
                let chunk = stderrHandle.availableData
                if chunk.isEmpty { break }
                data.append(chunk)
            }
            return data
        }

        do {
            try process.run()
            debugLog("Process.run() called, waiting for completion...")
        } catch {
            throw error
        }

        // Wait for process to complete
        process.waitUntilExit()
        debugLog("Process terminated with code \(process.terminationStatus)")

        // Get the collected output
        stdoutData = await stdoutTask.value
        stderrData = await stderrTask.value
        debugLog("Pipe data read complete (\(stdoutData.count) bytes stdout)")

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        return (process.terminationStatus, stdout, stderr)
    }

    /// Cancel the currently running process
    func cancel() {
        isCancelled = true
        currentProcess?.terminate()
        currentProcess = nil
    }

    /// Build a display string for a command (for console output)
    static func formatCommand(executable: URL, arguments: [String]) -> String {
        let execName = executable.lastPathComponent
        let args = arguments.map { arg in
            // Quote arguments containing spaces
            if arg.contains(" ") || arg.contains("/") {
                return "\"\(arg)\""
            }
            return arg
        }.joined(separator: " ")
        return "$ \(execName) \(args)"
    }
}

/// Errors that can occur during process execution
enum ProcessRunnerError: LocalizedError {
    case executableNotFound(URL)
    case processTerminated(Int32)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let url):
            return "Executable not found: \(url.path)"
        case .processTerminated(let code):
            return "Process terminated with exit code \(code)"
        case .cancelled:
            return "Process was cancelled"
        }
    }
}
