import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: ClipViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // URL Input Section
                urlInputSection

                // Video Info Section (shown after loading)
                if let videoInfo = viewModel.videoInfo {
                    videoInfoSection(videoInfo)
                }

                // Error message
                if let error = viewModel.loadError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.callout)
                }

                // Time Range Section (shown after video loads)
                if viewModel.videoInfo != nil {
                    timeRangeSection

                    outputSection

                    // Progress Section
                    if viewModel.isProcessing || viewModel.progress > 0 {
                        progressSection
                    }

                    // Console Section
                    ConsoleView(
                        output: viewModel.consoleOutput,
                        isExpanded: $viewModel.isConsoleExpanded
                    )

                    // Action Buttons
                    actionButtons
                }
            }
            .padding(20)
        }
        .frame(minWidth: 550, minHeight: 500)
    }

    // MARK: - URL Input Section

    private var urlInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Video URL")
                .font(.headline)

            HStack {
                TextField("Paste a link from YouTube, Vimeo, or other sites", text: $viewModel.urlInput)
                    .textFieldStyle(.roundedBorder)
                    .disabled(viewModel.isLoadingFormats || viewModel.isProcessing)
                    .onSubmit {
                        if !viewModel.urlInput.isEmpty && !viewModel.isLoadingFormats && !viewModel.isProcessing {
                            Task {
                                await viewModel.loadFormats()
                            }
                        }
                    }

                Button("Load Video") {
                    Task {
                        await viewModel.loadFormats()
                    }
                }
                .disabled(viewModel.urlInput.isEmpty || viewModel.isLoadingFormats || viewModel.isProcessing)
            }

            if viewModel.isLoadingFormats {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading video information...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Video Info Section

    private func videoInfoSection(_ videoInfo: VideoInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title and duration
            VStack(alignment: .leading, spacing: 4) {
                Text(videoInfo.title)
                    .font(.title3)
                    .fontWeight(.medium)
                    .lineLimit(2)

                Text("Duration: \(videoInfo.formattedDuration)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Format picker
            formatPickerSection(videoInfo)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    // MARK: - Format Picker Section

    private func formatPickerSection(_ videoInfo: VideoInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quality")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Picker("Quality", selection: $viewModel.selectedFormat) {
                ForEach(videoInfo.displayFormats) { format in
                    Text(formatLabel(for: format, in: videoInfo))
                        .tag(Optional(format))
                }
            }
            .labelsHidden()
            .frame(width: 200)

            // Re-encode checkbox (only shown when needed)
            if viewModel.formatNeedsReencode {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(isOn: $viewModel.reencodeToH264) {
                        Text("Convert to compatible format (x264)")
                            .font(.subheadline)
                    }

                    if let codec = viewModel.selectedFormat?.codec {
                        Text("The original format (\(codec.displayName)) may not play on all devices. Converting ensures it works everywhere.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func formatLabel(for format: VideoFormat, in videoInfo: VideoInfo) -> String {
        var label = format.displayLabel

        // Mark if it's the best quality
        if format.id == videoInfo.bestFormat?.id {
            label += " (Best)"
        }

        // Add codec info
        label += " - \(format.codec.displayName)"

        return label
    }

    // MARK: - Time Range Section

    private var timeRangeSection: some View {
        TimeRangeInputView(
            startTime: $viewModel.startTimeInput,
            endTime: $viewModel.endTimeInput,
            videoDuration: viewModel.videoInfo?.duration,
            validationMessage: viewModel.timeValidationMessage
        )
    }

    // MARK: - Output Section

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Save To")
                .font(.headline)

            HStack {
                TextField("Choose output location", text: outputPathBinding)
                    .textFieldStyle(.roundedBorder)
                    .disabled(true)

                Button("Choose...") {
                    viewModel.selectOutputFile()
                }
                .disabled(viewModel.isProcessing)
            }
        }
    }

    private var outputPathBinding: Binding<String> {
        Binding(
            get: { viewModel.outputURL?.path ?? "" },
            set: { _ in }
        )
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: viewModel.progress)

            Text(viewModel.progressMessage)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack {
            Spacer()

            if viewModel.isProcessing {
                Button("Cancel") {
                    viewModel.cancelClip()
                }
                .keyboardShortcut(.cancelAction)
            }

            Button("Create Clip") {
                viewModel.startClip()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canStartClip)
            .keyboardShortcut(.defaultAction)
        }
    }
}

#Preview {
    let dependencyManager = DependencyManager()
    let clipService = ClipService(dependencyManager: dependencyManager)
    let viewModel = ClipViewModel(clipService: clipService)

    // Set up some preview state
    viewModel.urlInput = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"

    return ContentView(viewModel: viewModel)
}
