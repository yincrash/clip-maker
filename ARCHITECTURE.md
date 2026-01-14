# yt-dlp Clip Maker - Architecture Document

## Overview

A macOS GUI application that wraps yt-dlp and ffmpeg functionality to download video clips from online sources. The app provides a user-friendly interface for specifying URLs, time ranges, format selection, and output location.

## Target User

Non-technical users who want to save clips from online videos without needing to understand command-line tools, codecs, or video processing.

**Design Philosophy**: While the UI should be approachable for beginners, the app should be transparent about what it's doing. Technical users should be able to see exact commands being run and understand the underlying operations.

## Core Features

1. **Dependency Management**
   - Download and manage yt-dlp binary (latest release from GitHub)
   - Download and manage ffmpeg binary (latest release)
   - Store binaries in Application Support directory
   - Check for updates on app launch
   - Clear explanation of what each dependency does and why it's needed
   - Links to official project pages for users who want to learn more

2. **URL Analysis**
   - Fetch available formats/qualities from URL using yt-dlp
   - Display codec information in user-friendly terms (not raw codec names)
   - Show available resolutions and bitrates
   - Detect if re-encoding will be required

3. **Clip Creation**
   - Start/end timestamp input
   - Output file location picker
   - Progress bar during download/processing
   - Option to re-encode to h264/x264 for maximum compatibility (checkbox, default on when needed)
   - Allow users to skip re-encoding if they prefer original format
   - Console output window showing live command output for transparency

4. **User Interface**
   - Single-window SwiftUI application
   - Clean, native macOS design
   - User-friendly language (avoid technical jargon where possible)

---

## Architecture

### Layer Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      UI Layer (SwiftUI)                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ ContentView │  │ FormatPicker│  │ ProgressView        │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   ViewModel Layer                            │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                   ClipViewModel                          ││
│  │  - URL input state                                       ││
│  │  - Format selection state                                ││
│  │  - Progress state                                        ││
│  │  - Error handling                                        ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Service Layer                             │
│  ┌──────────────────┐  ┌──────────────────┐                 │
│  │ DependencyManager│  │  ClipService     │                 │
│  │  - Download bins │  │  - Fetch formats │                 │
│  │  - Check updates │  │  - Create clips  │                 │
│  │  - Verify install│  │  - Monitor prog  │                 │
│  └──────────────────┘  └──────────────────┘                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  Process Execution Layer                     │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                ProcessRunner                             ││
│  │  - Execute yt-dlp/ffmpeg commands                        ││
│  │  - Stream stdout/stderr                                  ││
│  │  - Parse progress output                                 ││
│  │  - Handle cancellation                                   ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

---

## Component Details

### 1. DependencyManager

**Responsibility**: Download, install, and manage yt-dlp and ffmpeg binaries.

**Location**: `~/Library/Application Support/yt-dlp Clip Maker/bin/`

**Implementation**:
```swift
class DependencyManager: ObservableObject {
    @Published var ytDlpStatus: DependencyStatus
    @Published var ffmpegStatus: DependencyStatus

    func checkDependencies() async
    func downloadYtDlp() async throws
    func downloadFfmpeg() async throws
    func ytDlpPath() -> URL?
    func ffmpegPath() -> URL?
}

enum DependencyStatus {
    case notInstalled
    case checking
    case downloading(progress: Double)
    case installed(version: String)
    case updateAvailable(current: String, latest: String)
    case error(String)
}

struct DependencyInfo {
    let name: String
    let description: String        // User-friendly explanation
    let learnMoreURL: URL          // Link to official project page
    let downloadURL: URL           // Where to fetch the binary
}

// Dependency metadata for UI display
static let ytDlpInfo = DependencyInfo(
    name: "yt-dlp",
    description: "A tool that enables downloading videos from YouTube and many other websites. This app uses it to fetch video information and download clips.",
    learnMoreURL: URL(string: "https://github.com/yt-dlp/yt-dlp")!,
    downloadURL: URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos")!
)

static let ffmpegInfo = DependencyInfo(
    name: "FFmpeg",
    description: "A powerful tool for processing video and audio files. This app uses it to trim videos to your selected time range and convert them to compatible formats.",
    learnMoreURL: URL(string: "https://ffmpeg.org")!,
    downloadURL: URL(string: "https://evermeet.cx/ffmpeg/getrelease/zip")!
)
```

**Binary Sources**:
- yt-dlp: `https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos`
- ffmpeg: `https://evermeet.cx/ffmpeg/` (provides macOS static builds)

**Considerations**:
- Binaries need execute permissions (`chmod +x`)
- Consider code signing implications
- Store version info for update checking

---

### 2. ClipService

**Responsibility**: Interact with yt-dlp and ffmpeg to fetch video info and create clips.

**Implementation**:
```swift
class ClipService {
    private let processRunner: ProcessRunner
    private let dependencyManager: DependencyManager

    // Fetch available formats from URL
    func fetchFormats(url: String) async throws -> VideoInfo

    // Create a clip with specified parameters
    func createClip(request: ClipRequest) -> AsyncThrowingStream<ClipProgress, Error>
}

struct VideoInfo {
    let title: String
    let duration: TimeInterval
    let formats: [VideoFormat]
    let thumbnailURL: URL?
}

struct VideoFormat: Identifiable {
    let id: String           // format ID from yt-dlp
    let resolution: String   // e.g., "1920x1080"
    let codec: VideoCodec    // h264, vp9, av1, etc.
    let fps: Int
    let bitrate: Int?        // in kbps
    let filesize: Int?       // estimated in bytes
    let hasAudio: Bool
    let audioCodec: String?
}

enum VideoCodec: String {
    case h264 = "avc1"
    case h265 = "hev1"
    case vp9 = "vp9"
    case av1 = "av01"
    case unknown

    var requiresReencode: Bool {
        self != .h264
    }
}

struct ClipRequest {
    let url: String
    let formatId: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let outputURL: URL
    let reencode: Bool       // User choice: convert to h264 for compatibility
}

enum ClipProgress {
    case started
    case downloading(percent: Double)
    case processing(percent: Double)
    case completed(outputURL: URL)
}
```

**yt-dlp Commands**:
```bash
# Fetch format info (JSON output)
yt-dlp -J "<url>"

# Download clip with time range
yt-dlp \
  --external-downloader ffmpeg \
  --external-downloader-args "ffmpeg_i:-ss <start> -to <end>" \
  -f "<format_id>" \
  --merge-output-format mp4 \
  -o "<output>" \
  "<url>"

# With re-encoding to h264
yt-dlp \
  --external-downloader ffmpeg \
  --external-downloader-args "ffmpeg_i:-ss <start> -to <end>" \
  -f "<format_id>" \
  --postprocessor-args "ffmpeg:-c:v libx264 -preset medium -crf 23 -c:a aac" \
  --merge-output-format mp4 \
  -o "<output>" \
  "<url>"
```

---

### 3. ProcessRunner

**Responsibility**: Execute shell commands and stream output.

**Implementation**:
```swift
actor ProcessRunner {
    func run(
        executable: URL,
        arguments: [String],
        onOutput: @escaping (String) -> Void
    ) async throws -> Int32

    func cancel()
}
```

**Key Features**:
- Use `Process` (Foundation) to spawn yt-dlp/ffmpeg
- Capture stdout/stderr via pipes
- Parse progress from yt-dlp output (percentage patterns)
- Support cancellation via `process.terminate()`

---

### 4. ClipViewModel

**Responsibility**: Manage UI state and coordinate between views and services.

**Implementation**:
```swift
@MainActor
class ClipViewModel: ObservableObject {
    // Input state
    @Published var urlInput: String = ""
    @Published var startTime: String = "00:00:00"
    @Published var endTime: String = "00:00:00"
    @Published var selectedFormat: VideoFormat?
    @Published var outputURL: URL?

    // Video info state
    @Published var videoInfo: VideoInfo?
    @Published var isLoadingFormats: Bool = false

    // Progress state
    @Published var isProcessing: Bool = false
    @Published var progress: Double = 0
    @Published var progressMessage: String = ""

    // Console output
    @Published var consoleOutput: String = ""   // Live command output
    @Published var isConsoleExpanded: Bool = true
    @Published var currentCommand: String = ""  // Command being executed

    // Error state
    @Published var errorMessage: String?

    // Re-encoding option
    @Published var reencodeToH264: Bool = true  // User-controllable checkbox

    // Computed
    var formatNeedsReencode: Bool { selectedFormat?.codec.requiresReencode ?? false }
    var canStartClip: Bool { /* validation logic */ }

    // Actions
    func loadFormats() async
    func selectOutputFile()
    func startClip() async
    func cancelClip()
}
```

---

### 5. UI Components

#### ContentView (Main Window)
```
┌────────────────────────────────────────────────────────────┐
│  yt-dlp Clip Maker                                         │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  Video URL                                                 │
│  [________________________________________________]       │
│  Paste a link from YouTube, Vimeo, or other sites         │
│                                            [Load Video]    │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  "Example Video Title"                               │  │
│  │  Duration: 10:32                                     │  │
│  │                                                      │  │
│  │  Quality: [1080p (Best) ▼]                          │  │
│  │                                                      │  │
│  │  ☑ Convert to compatible format (x264)              │  │
│  │    The original format (VP9) may not play on all    │  │
│  │    devices. Converting ensures it works everywhere. │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                            │
│  Clip Range                                                │
│  Start: [00:01:30]         End: [00:02:45]                │
│                                                            │
│  Save To                                                   │
│  [~/Downloads/clip.mp4                  ] [Choose...]      │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  ████████████████░░░░░░░░░░░░░░░  45%                │  │
│  │  Downloading video...                                │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Console Output                                    [^] │  │
│  ├──────────────────────────────────────────────────────┤  │
│  │ $ yt-dlp --external-downloader ffmpeg ...            │  │
│  │ [download] Downloading video 1 of 1                  │  │
│  │ [download]  45.2% of 125.3MiB at 2.5MiB/s ETA 00:32 │  │
│  │ frame= 1024 fps=30 q=28.0 size=   15360kB time=...  │  │
│  │ █                                                    │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                            │
│                              [Cancel]  [Create Clip]       │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

**Notes on ContentView:**
- Quality dropdown shows user-friendly labels like "1080p (Best)", "720p", "480p"
- Re-encode checkbox only appears when format is not h264
- Checkbox label includes "(x264)" so technical users know the exact codec
- Checkbox description shows the original format name (e.g., "VP9", "AV1")
- Checkbox is ON by default with explanation of why conversion helps
- User can uncheck to keep original format if they prefer
- Console output panel is collapsible (toggle with [^] button)
- Console shows the exact command being run and live stdout/stderr
- Console uses monospace font and auto-scrolls to latest output

#### OnboardingView (First Launch / Dependencies Missing)
```
┌────────────────────────────────────────────────────────────┐
│                                                            │
│                    Welcome to Clip Maker                   │
│                                                            │
│     Before you can start saving video clips, this app     │
│     needs to download two small helper programs.          │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  yt-dlp                                              │  │
│  │  Fetches videos from YouTube and other websites.     │  │
│  │  Learn more: https://github.com/yt-dlp/yt-dlp        │  │
│  │                                                      │  │
│  │  Status: ✓ Ready                                     │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  FFmpeg                                              │  │
│  │  Trims and converts video files.                     │  │
│  │  Learn more: https://ffmpeg.org                      │  │
│  │                                                      │  │
│  │  Status: ████████░░░░░░░░░░  42% Downloading...     │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                            │
│     These tools are open source and free to use.          │
│     They will be stored in your Application Support       │
│     folder and only used by this app.                     │
│                                                            │
│                                   [Download & Continue]    │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

**Notes on OnboardingView:**
- Each dependency has a clear description of what it does
- "Learn more" links open the official project websites in browser
- Explains where files will be stored
- Reassures users these are trusted open-source tools
- Button changes from "Download & Continue" → "Continue" when ready

#### ConsoleView (Command Output Panel)
```
┌──────────────────────────────────────────────────────────┐
│ Console Output                                        [^] │
├──────────────────────────────────────────────────────────┤
│ $ yt-dlp --external-downloader ffmpeg \                  │
│     --external-downloader-args "ffmpeg_i:-ss 00:01:30    │
│     -to 00:02:45" -f "137+140" --merge-output-format mp4 │
│     -o "/Users/me/clip.mp4" "https://youtube.com/..."    │
│                                                          │
│ [download] Downloading video 1 of 1                      │
│ [download]  45.2% of 125.3MiB at 2.5MiB/s ETA 00:32     │
│ [ffmpeg] Merging formats into "clip.mp4"                 │
│ frame= 1024 fps=30 q=28.0 size=   15360kB time=00:00:34 │
│ █                                                        │
└──────────────────────────────────────────────────────────┘
```

**Notes on ConsoleView:**
- Collapsible panel (starts expanded during processing)
- Shows full command with all arguments at the top
- Monospace font (SF Mono or system monospace)
- Dark background with light text (terminal aesthetic)
- Auto-scrolls to bottom as new output arrives
- Scrollable for reviewing past output
- Copy button or right-click to copy output

#### SettingsView (Preferences Window)
- Show installed binary versions
- Check for updates button
- Re-download binaries option
- Links to yt-dlp and ffmpeg websites

---

## File Structure

```
yt-dlp Clip Maker/
├── yt-dlp Clip Maker/
│   ├── App/
│   │   └── yt_dlp_Clip_MakerApp.swift
│   │
│   ├── Views/
│   │   ├── ContentView.swift          # Main clip creation UI
│   │   ├── FormatPickerView.swift     # Format selection component
│   │   ├── TimeInputView.swift        # Timestamp input component
│   │   ├── ProgressView.swift         # Download/process progress
│   │   ├── ConsoleView.swift          # Collapsible command output panel
│   │   ├── OnboardingView.swift       # First-launch setup
│   │   └── SettingsView.swift         # Preferences window
│   │
│   ├── ViewModels/
│   │   └── ClipViewModel.swift        # Main view model
│   │
│   ├── Services/
│   │   ├── DependencyManager.swift    # Binary management
│   │   ├── ClipService.swift          # yt-dlp/ffmpeg operations
│   │   └── ProcessRunner.swift        # Command execution
│   │
│   ├── Models/
│   │   ├── VideoInfo.swift            # Video metadata
│   │   ├── VideoFormat.swift          # Format info
│   │   ├── ClipRequest.swift          # Clip parameters
│   │   └── ClipProgress.swift         # Progress updates
│   │
│   ├── Utilities/
│   │   ├── TimeFormatter.swift        # HH:MM:SS parsing
│   │   └── FileSizeFormatter.swift    # Human-readable sizes
│   │
│   └── Assets.xcassets/
│
├── yt-dlp Clip MakerTests/
│   ├── DependencyManagerTests.swift
│   ├── ClipServiceTests.swift
│   └── TimeFormatterTests.swift
│
└── yt-dlp Clip MakerUITests/
```

---

## Data Flow

### 1. Loading Formats
```
User enters URL → [Load Formats] clicked
    │
    ▼
ClipViewModel.loadFormats()
    │
    ▼
ClipService.fetchFormats(url)
    │
    ▼
ProcessRunner executes: yt-dlp -J "<url>"
    │
    ▼
Parse JSON output → VideoInfo
    │
    ▼
ClipViewModel.videoInfo updated
    │
    ▼
UI displays formats, auto-selects best h264 option
```

### 2. Creating Clip
```
User clicks [Create Clip]
    │
    ▼
ClipViewModel.startClip()
    │
    ▼
ClipService.createClip(request)
    │
    ▼
ProcessRunner executes yt-dlp with ffmpeg
    │
    ├──► stdout parsed for progress → UI updates
    │
    ▼
Process completes
    │
    ▼
ClipViewModel.progress = 1.0, show completion
```

---

## Error Handling

| Error Type | Handling |
|------------|----------|
| Invalid URL | Show inline validation error |
| Network failure | Show alert with retry option |
| Format unavailable | Remove from list, show message |
| Disk full | Show alert with space needed |
| Binary missing | Redirect to onboarding |
| Process crash | Show error log, offer retry |
| User cancelled | Clean up temp files, reset UI |

---

## Security Considerations

1. **Binary Downloads**
   - Verify checksums when available
   - Download over HTTPS only
   - Consider notarization implications

2. **Command Injection**
   - Never pass user input directly to shell
   - Use Process with argument arrays (not shell strings)
   - Validate URLs before passing to yt-dlp

3. **File System**
   - Use sandboxed Application Support directory
   - Request permissions for output location via NSSavePanel
   - Clean up temp files on cancellation

---

## Future Enhancements (Out of Scope for V1)

- Batch processing multiple clips
- Clip preview before download
- Preset management (quality presets)
- History of created clips
- Integration with system Share menu
- Keyboard shortcuts
- Touch Bar support
- Menu bar quick-clip mode

---

## Implementation Order

1. **Phase 1: Foundation**
   - ProcessRunner implementation
   - DependencyManager (download yt-dlp and ffmpeg)
   - Basic onboarding UI

2. **Phase 2: Core Functionality**
   - ClipService format fetching
   - ClipViewModel
   - Main ContentView (URL input, format display)

3. **Phase 3: Clip Creation**
   - Time input components
   - Output file picker
   - Clip execution with progress

4. **Phase 4: Polish**
   - Error handling improvements
   - Settings view
   - Update checking
   - UI refinements
