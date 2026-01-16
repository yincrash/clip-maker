# yt-dlp Clip Maker

A macOS app that creates video clips from online videos using [yt-dlp](https://github.com/yt-dlp/yt-dlp) and [ffmpeg](https://ffmpeg.org/).

## Why?

This app was created specifically for clipping long streams (VODs, livestream archives, etc.). When a stream is seekable (typically after it's finished processing by the provider), yt-dlp can download just the portion between your specified timestamps without downloading the entire video. This makes it practical to grab a 2-minute clip from a 10-hour stream.

## Features

- Download clips from any yt-dlp supported site (YouTube, Vimeo, etc.)
- Specify start and end times to extract specific portions
- Format selection with automatic filtering of non-seekable streams
- Re-encoding option for non-H.264 codecs
- Real-time console output during clip creation
- Automatic dependency management (downloads yt-dlp and ffmpeg if needed)
- Support for system-installed binaries via Homebrew

## Requirements

- macOS 15.0 or later
- Xcode 26.0+ (for building from source)

## Installation

### From Release

Download the latest DMG from the [Releases](https://github.com/yincrash/clip-maker/releases) page.

### Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/yincrash/clip-maker.git
   cd clip-maker
   ```

2. Copy the developer settings template and fill in your Team ID:
   ```bash
   cp "yt-dlp Clip Maker/DeveloperSettings.xcconfig.template" "yt-dlp Clip Maker/DeveloperSettings.xcconfig"
   ```

   Edit `DeveloperSettings.xcconfig` and set your Apple Developer Team ID.

3. Open the project in Xcode:
   ```bash
   open "yt-dlp Clip Maker/yt-dlp Clip Maker.xcodeproj"
   ```

4. Build and run (Cmd+R)

## Dependencies

The app requires yt-dlp and ffmpeg to function. You have two options:

### Option 1: Let the app download them
On first launch, the app will offer to download standalone binaries to its Application Support directory. Note that the standalone yt-dlp binary has a [slow startup time](https://github.com/yt-dlp/yt-dlp/issues/10425) due to how it's packaged.

### Option 2: Install via [Homebrew](https://brew.sh/) (recommended)
```bash
brew install yt-dlp ffmpeg
```

The Homebrew version of yt-dlp starts much faster than the standalone binary. The app will automatically detect system-installed binaries. You can switch between app-bundled and system versions in Settings.

## Usage

1. Paste a video URL
2. Click "Fetch Formats" to load available formats
3. Select your preferred format
4. Enter start and end times (HH:MM:SS format)
5. Click "Create Clip"
6. Choose where to save the clip

## License

MIT License
