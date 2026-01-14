import Foundation

/// Protocol for finding binaries in the system
protocol PathFinderProtocol {
    func findBinary(named name: String) -> URL?
    func fileExists(at path: URL) -> Bool
}

/// Default implementation that searches common system paths
class PathFinder: PathFinderProtocol {
    private let fileManager: FileManager
    private let searchPaths: [String]

    /// Common paths where binaries might be installed
    static let defaultSearchPaths = [
        "/usr/local/bin",
        "/opt/homebrew/bin",
        "/usr/bin",
        "/bin",
        "/opt/local/bin"
    ]

    init(
        fileManager: FileManager = .default,
        searchPaths: [String] = PathFinder.defaultSearchPaths
    ) {
        self.fileManager = fileManager
        self.searchPaths = searchPaths
    }

    func fileExists(at path: URL) -> Bool {
        fileManager.fileExists(atPath: path.path)
    }

    /// Find a binary by searching common paths, then falling back to `which`
    func findBinary(named name: String) -> URL? {
        // First check common paths directly
        if let path = findInCommonPaths(name) {
            return path
        }

        // Fall back to `which` command
        return findUsingWhich(name)
    }

    /// Search for a binary in the configured search paths
    func findInCommonPaths(_ name: String) -> URL? {
        for dir in searchPaths {
            let path = URL(fileURLWithPath: dir).appendingPathComponent(name)
            if fileManager.fileExists(atPath: path.path) {
                return path
            }
        }
        return nil
    }

    /// Use the `which` command to find a binary
    func findUsingWhich(_ name: String) -> URL? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = nil

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return URL(fileURLWithPath: path)
                }
            }
        } catch {
            // Ignore errors from which
        }

        return nil
    }
}

/// Mock path finder for testing
class MockPathFinder: PathFinderProtocol {
    var existingPaths: Set<String> = []
    var binaryLocations: [String: URL] = [:]

    func findBinary(named name: String) -> URL? {
        binaryLocations[name]
    }

    func fileExists(at path: URL) -> Bool {
        existingPaths.contains(path.path)
    }

    func addBinary(_ name: String, at path: String) {
        let url = URL(fileURLWithPath: path)
        binaryLocations[name] = url
        existingPaths.insert(path)
    }

    func addExistingPath(_ path: String) {
        existingPaths.insert(path)
    }
}
