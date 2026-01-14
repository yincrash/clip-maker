import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dependencyManager: DependencyManager
    @State private var isCheckingForUpdates = false

    var body: some View {
        Form {
            Section("Dependencies") {
                ytDlpRow
                ffmpegRow

                if case .installed(_, .appBundle) = dependencyManager.ytDlpStatus {
                    Text("Tip: Installing yt-dlp via Homebrew (`brew install yt-dlp`) is faster than the standalone binary.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Button("Check for Updates") {
                    checkForUpdates()
                }
                .disabled(isCheckingForUpdates)

                Button("Re-download Dependencies") {
                    redownloadDependencies()
                }
                .disabled(isCheckingForUpdates)
            }

            Section("About") {
                LabeledContent("Binary Location") {
                    Text(dependencyManager.binDirectory.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }

                HStack {
                    Link("yt-dlp Project", destination: DependencyInfo.ytDlp.learnMoreURL)
                    Text("  |  ")
                        .foregroundColor(.secondary)
                    Link("FFmpeg Project", destination: DependencyInfo.ffmpeg.learnMoreURL)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 400)
    }

    private var ytDlpRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent(DependencyInfo.ytDlp.name) {
                HStack(spacing: 8) {
                    statusView(for: dependencyManager.ytDlpStatus)
                }
            }

            // Show source switcher if both app and system versions are available
            if dependencyManager.hasAppYtDlp && dependencyManager.systemYtDlpPath != nil {
                HStack(spacing: 12) {
                    Text("Source:")
                        .foregroundColor(.secondary)
                        .font(.caption)

                    Picker("", selection: Binding(
                        get: { dependencyManager.ytDlpSource == .systemPath ? "system" : "app" },
                        set: { newValue in
                            if newValue == "system" {
                                dependencyManager.useSystemYtDlp()
                            } else {
                                dependencyManager.useAppYtDlp()
                            }
                        }
                    )) {
                        Text("App").tag("app")
                        Text("System").tag("system")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }
                .padding(.leading, 4)
            } else if dependencyManager.systemYtDlpPath != nil && !dependencyManager.hasAppYtDlp {
                // System available but no app bundle - offer to use system
                if case .foundInPath = dependencyManager.ytDlpStatus {
                    Button("Use System Version") {
                        dependencyManager.useSystemYtDlp()
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
            }
        }
    }

    private var ffmpegRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent(DependencyInfo.ffmpeg.name) {
                HStack(spacing: 8) {
                    statusView(for: dependencyManager.ffmpegStatus)
                }
            }

            // Show source switcher if both app and system versions are available
            if dependencyManager.hasAppFfmpeg && dependencyManager.systemFfmpegPath != nil {
                HStack(spacing: 12) {
                    Text("Source:")
                        .foregroundColor(.secondary)
                        .font(.caption)

                    Picker("", selection: Binding(
                        get: { dependencyManager.ffmpegSource == .systemPath ? "system" : "app" },
                        set: { newValue in
                            if newValue == "system" {
                                dependencyManager.useSystemFfmpeg()
                            } else {
                                dependencyManager.useAppFfmpeg()
                            }
                        }
                    )) {
                        Text("App").tag("app")
                        Text("System").tag("system")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }
                .padding(.leading, 4)
            } else if dependencyManager.systemFfmpegPath != nil && !dependencyManager.hasAppFfmpeg {
                // System available but no app bundle - offer to use system
                if case .foundInPath = dependencyManager.ffmpegStatus {
                    Button("Use System Version") {
                        dependencyManager.useSystemFfmpeg()
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
            }
        }
    }

    private func dependencyRow(info: DependencyInfo, status: DependencyStatus) -> some View {
        LabeledContent(info.name) {
            HStack(spacing: 8) {
                statusView(for: status)
            }
        }
    }

    @ViewBuilder
    private func statusView(for status: DependencyStatus) -> some View {
        switch status {
        case .notInstalled:
            Label("Not installed", systemImage: "circle")
                .foregroundColor(.secondary)

        case .checking:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text("Checking...")
            }

        case .downloading(let progress):
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .frame(width: 80)
                Text("\(Int(progress * 100))%")
                    .monospacedDigit()
            }

        case .installed(let version, let source):
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("v\(version)")
                Text("(\(source.displayName))")
                    .foregroundColor(.secondary)
            }

        case .foundInPath(_, let version):
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.orange)
                Text("v\(version) (found in system)")
            }

        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
        }
    }

    private func checkForUpdates() {
        isCheckingForUpdates = true
        Task {
            await dependencyManager.checkDependencies()
            isCheckingForUpdates = false
        }
    }

    private func redownloadDependencies() {
        isCheckingForUpdates = true
        Task {
            do {
                try await dependencyManager.downloadAll()
            } catch {
                print("Error downloading dependencies: \(error)")
            }
            isCheckingForUpdates = false
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(DependencyManager())
}
