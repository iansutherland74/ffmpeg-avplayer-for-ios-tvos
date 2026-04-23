# FFmpegAVPlayerVisionOS

Local Swift package that links against FFmpeg 8.1 visionOS XCFrameworks and
integrates the 2D-to-3D stereo pipeline from `visionos-2d-to-3d`.

## Prerequisites

- A local checkout of ffmpeg-kit-8.1 with built artifacts in:
  - ../ffmpeg-kit-8.1/prebuilt-visionos/FFmpegXCFrameworks
- The 2D-to-3D package in:
  - ../ffmpeg-kit-8.1/visionos-2d-to-3d

## Setup

From repository root:

```bash
./scripts/setup-visionos-from-ffmpeg-kit-8.1.sh
```

Then add local package path `visionOS/` in Xcode.

The package has a local dependency on `../../ffmpeg-kit-8.1/visionos-2d-to-3d`,
so keep this repository adjacent to your ffmpeg-kit-8.1 checkout.

## Package layout

- Package.swift
- Sources/FFmpegAVPlayerVisionOS/FFmpegBridge.swift
- Sources/FFmpegAVPlayerVisionOS/VisionStereoPipeline.swift
- FFmpegXCFrameworks/ (copied by setup script)

## Notes

- This package intentionally bypasses the legacy prebuilt `AVPlayerTouch.framework`.
- It is the recommended path for visionOS integration with FFmpeg 8.1.

## Quick usage

```swift
import CoreML
import FFmpegAVPlayerVisionOS
import VisionOS2Dto3D

let config = MLModelConfiguration()
config.computeUnits = .all
let model = try DepthAnythingModelLoader.loadBundledModel(configuration: config)

let pipeline = try VisionStereoPipeline(
  model: model,
  maxDisparity: 0.035,
  temporalSmoothing: 0.7
)

// In your decoded-frame loop:
try pipeline.processAndEnqueue(
  pixelBuffer: decodedFrame,
  presentationTime: pts,
  duration: frameDuration
)

// Attach pipeline.renderer to your video render path.
```
