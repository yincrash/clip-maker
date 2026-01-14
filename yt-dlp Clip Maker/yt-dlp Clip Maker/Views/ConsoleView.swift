import SwiftUI

/// Collapsible console output panel showing live command output
struct ConsoleView: View {
    let output: String
    @Binding var isExpanded: Bool

    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Text("Console Output")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    // Copy button
                    if isExpanded && !output.isEmpty {
                        Button(action: copyToClipboard) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Copy to clipboard")
                    }

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
            }
            .buttonStyle(.plain)

            // Console content
            if isExpanded {
                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        Text(output.isEmpty ? "Command output will appear here..." : output)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(output.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .textSelection(.enabled)
                            .id("consoleBottom")
                    }
                    .frame(height: 150)
                    .background(Color(nsColor: .textBackgroundColor))
                    .onChange(of: output) { _, _ in
                        withAnimation {
                            proxy.scrollTo("consoleBottom", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
    }
}

#Preview("With Output") {
    ConsoleView(
        output: """
        $ yt-dlp --external-downloader ffmpeg \\
            --external-downloader-args "ffmpeg_i:-ss 00:01:30 -to 00:02:45" \\
            -f "137+140" --merge-output-format mp4 \\
            -o "/Users/me/clip.mp4" "https://youtube.com/watch?v=abc123"

        [download] Downloading video 1 of 1
        [download]  45.2% of 125.3MiB at 2.5MiB/s ETA 00:32
        [ffmpeg] Merging formats into "clip.mp4"
        frame= 1024 fps=30 q=28.0 size=   15360kB time=00:00:34
        """,
        isExpanded: .constant(true)
    )
    .frame(width: 500)
    .padding()
}

#Preview("Collapsed") {
    ConsoleView(
        output: "Some output",
        isExpanded: .constant(false)
    )
    .frame(width: 500)
    .padding()
}

#Preview("Empty") {
    ConsoleView(
        output: "",
        isExpanded: .constant(true)
    )
    .frame(width: 500)
    .padding()
}
