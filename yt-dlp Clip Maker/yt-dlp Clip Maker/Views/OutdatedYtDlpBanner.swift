import SwiftUI

/// A dismissible warning shown when the active yt-dlp build is more than a couple of
/// months old. Stale yt-dlp builds frequently fail to download from YouTube, so this
/// nudges the user to update — either in-app (for app-managed copies) or via their
/// package manager (for system/Homebrew copies).
struct OutdatedYtDlpBanner: View {
    @ObservedObject var dependencyManager: DependencyManager

    @State private var isDismissed = false
    @State private var isUpdating = false
    @State private var errorMessage: String?

    var body: some View {
        if dependencyManager.isYtDlpOutdated && !isDismissed {
            VStack(alignment: .leading, spacing: 8) {
                header
                message

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                actions
            }
            .padding(12)
            .background(Color.yellow.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.yellow.opacity(0.6), lineWidth: 1)
            )
            .cornerRadius(8)
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(headerText)
                .font(.subheadline)
                .fontWeight(.semibold)
            Spacer()
            Button {
                isDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Dismiss")
        }
    }

    private var message: some View {
        Text("Outdated versions of yt-dlp often fail to download from YouTube. Updating usually fixes clips that won't download or come out wrong.")
            .font(.caption)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var actions: some View {
        if isUpdating {
            HStack(spacing: 8) {
                if case .downloading(let progress) = dependencyManager.ytDlpStatus {
                    ProgressView(value: progress)
                        .frame(width: 120)
                    Text("Updating… \(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                } else {
                    ProgressView()
                        .controlSize(.small)
                    Text("Updating…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } else if dependencyManager.ytDlpSource == .systemPath {
            // System / Homebrew install — the app shouldn't replace it silently.
            VStack(alignment: .leading, spacing: 6) {
                Text("Update your system copy from Terminal, then click Re-check:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("brew upgrade yt-dlp")
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(4)

                HStack(spacing: 12) {
                    Button("Re-check") { recheck() }
                        .controlSize(.small)
                    Button("Download Latest for This App") { update() }
                        .controlSize(.small)
                }
            }
        } else {
            // App-managed copy — we can download the latest directly.
            Button("Update Now") { update() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }

    private var headerText: String {
        if let age = dependencyManager.ytDlpAgeDescription {
            return "yt-dlp is \(age) old"
        }
        return "yt-dlp is out of date"
    }

    // MARK: - Actions

    private func update() {
        isUpdating = true
        errorMessage = nil
        Task {
            do {
                try await dependencyManager.downloadYtDlp()
            } catch {
                errorMessage = error.localizedDescription
            }
            isUpdating = false
        }
    }

    private func recheck() {
        errorMessage = nil
        Task {
            await dependencyManager.checkDependencies()
        }
    }
}

#Preview {
    OutdatedYtDlpBanner(dependencyManager: DependencyManager())
        .padding()
        .frame(width: 520)
}
