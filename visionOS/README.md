# FFmpegAVPlayerVisionOS

Local Swift package that links against FFmpeg 8.1 visionOS XCFrameworks.

## Prerequisites

- A local checkout of ffmpeg-kit-8.1 with built artifacts in:
  - ../ffmpeg-kit-8.1/prebuilt-visionos/FFmpegXCFrameworks

## Setup

From repository root:

```bash
./scripts/setup-visionos-from-ffmpeg-kit-8.1.sh
```

Then add local package path `visionOS/` in Xcode.

## Package layout

- Package.swift
- Sources/FFmpegAVPlayerVisionOS/FFmpegBridge.swift
- FFmpegXCFrameworks/ (copied by setup script)

## Notes

- This package intentionally bypasses the legacy prebuilt `AVPlayerTouch.framework`.
- It is the recommended path for visionOS integration with FFmpeg 8.1.
