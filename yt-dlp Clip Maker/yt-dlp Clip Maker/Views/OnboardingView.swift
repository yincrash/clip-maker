import SwiftUI

struct OnboardingView: View {
    @ObservedObject var dependencyManager: DependencyManager
    @State private var isDownloading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("Welcome to Clip Maker")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Before you can start saving video clips, this app needs two helper programs. Click below to download them.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 40)
            .padding(.top, 24)

            // Dependencies
            VStack(spacing: 12) {
                DependencyCard(
                    info: DependencyInfo.ytDlp,
                    status: dependencyManager.ytDlpStatus,
                    onDownload: {
                        downloadYtDlp()
                    },
                    onUseSystem: {
                        dependencyManager.useSystemYtDlp()
                    }
                )

                DependencyCard(
                    info: DependencyInfo.ffmpeg,
                    status: dependencyManager.ffmpegStatus,
                    onDownload: {
                        downloadFfmpeg()
                    },
                    onUseSystem: {
                        dependencyManager.useSystemFfmpeg()
                    }
                )
            }
            .padding(.horizontal, 24)

            // Info text
            VStack(spacing: 4) {
                Text("These tools are open source and free to use.")
                Text("Downloaded copies will be stored in your Application Support folder.")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            Spacer()

            // Action button
            Button(action: downloadOrContinue) {
                if isDownloading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Downloading...")
                    }
                } else if dependencyManager.allDependenciesReady {
                    Text("Continue")
                } else {
                    Text("Download & Continue")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isDownloading)
            .padding(.bottom, 32)
        }
        .frame(minWidth: 520, minHeight: 480)
        .task {
            await dependencyManager.checkDependencies()
        }
    }

    private func downloadOrContinue() {
        guard !dependencyManager.allDependenciesReady else {
            return
        }

        isDownloading = true
        errorMessage = nil

        Task {
            do {
                // Download only missing dependencies
                if !dependencyManager.ytDlpStatus.isReady {
                    try await dependencyManager.downloadYtDlp()
                }
                if !dependencyManager.ffmpegStatus.isReady {
                    try await dependencyManager.downloadFfmpeg()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isDownloading = false
        }
    }

    private func downloadYtDlp() {
        isDownloading = true
        errorMessage = nil
        Task {
            do {
                try await dependencyManager.downloadYtDlp()
            } catch {
                errorMessage = error.localizedDescription
            }
            isDownloading = false
        }
    }

    private func downloadFfmpeg() {
        isDownloading = true
        errorMessage = nil
        Task {
            do {
                try await dependencyManager.downloadFfmpeg()
            } catch {
                errorMessage = error.localizedDescription
            }
            isDownloading = false
        }
    }
}

struct DependencyCard: View {
    let info: DependencyInfo
    let status: DependencyStatus
    var onDownload: (() -> Void)?
    var onUseSystem: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(info.name)
                    .font(.headline)

                Spacer()

                Link("Learn more", destination: info.learnMoreURL)
                    .font(.caption)
            }

            Text(info.description)
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Status and actions
            HStack(spacing: 12) {
                statusView

                Spacer()

                actionButtons
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .notInstalled:
            Label("Not installed", systemImage: "circle")
                .font(.caption)
                .foregroundColor(.secondary)

        case .checking:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.mini)
                Text("Checking...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

        case .downloading(let progress):
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .frame(width: 80)
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

        case .installed(let version, let source):
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("v\(version)")
                    .font(.caption)
                Text("(\(source.displayName))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

        case .foundInPath(let path, let version):
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                    Text("v\(version) found at \(path)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if info.name == "yt-dlp" {
                    Text("Recommended: Homebrew version is faster than the standalone binary.")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }

        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundColor(.red)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch status {
        case .notInstalled:
            Button("Download") {
                onDownload?()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

        case .foundInPath:
            HStack(spacing: 8) {
                Button("Use This") {
                    onUseSystem?()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Download Latest") {
                    onDownload?()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

        case .error:
            Button("Retry") {
                onDownload?()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

        default:
            EmptyView()
        }
    }
}

#Preview {
    OnboardingView(dependencyManager: DependencyManager())
}
