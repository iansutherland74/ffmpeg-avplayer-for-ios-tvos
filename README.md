
[![](https://dl.dropboxusercontent.com/u/87201024/avplayer/banner.jpg)](https://dl.dropboxusercontent.com/u/87201024/avplayer/banner.jpg)

A tiny but powerful av player framework for iOS and Apple TV OS. The SDK can play the most audio and video formats (Includes network audio and video streams), no convert hassles, no VLC and SDL dependent.

AVPlayer framework is written for iOS and Apple TV OS developers who want to add powerful av player to their app using a couple lines of code. Behind the scenes av player relies on the iOS OpenGL ES 2.0 framework and the open source LGPL licensed FFmpeg library.

## visionOS + FFmpeg 8.1 (new path)

This repository now includes a **visionOS integration path** that is aligned with
the FFmpeg 8.1 XCFramework artifacts built in:

- ../ffmpeg-kit-8.1/prebuilt-visionos/FFmpegXCFrameworks
- ../ffmpeg-kit-8.1/visionos-2d-to-3d

Important:

- The legacy `AVPlayerTouch.framework` binary in this repo is prebuilt for old iOS/tvOS targets and is not a native visionOS framework.
- For visionOS, use the new local Swift package under `visionOS/` that links directly to FFmpeg 8.1 XCFrameworks.

### Setup

1. Copy FFmpeg 8.1 visionOS XCFrameworks into this repo:

```bash
./scripts/setup-visionos-from-ffmpeg-kit-8.1.sh
```

Optional source override:

```bash
./scripts/setup-visionos-from-ffmpeg-kit-8.1.sh /absolute/path/to/FFmpegXCFrameworks
```

2. Add local package from `visionOS/` in Xcode.
3. Import `FFmpegAVPlayerVisionOS` and verify linkage:

```swift
import FFmpegAVPlayerVisionOS

let formatVersion = FFmpegBridge.avformatVersion()
let codecVersion = FFmpegBridge.avcodecVersion()
print(formatVersion, codecVersion)
```

### What this gives you

- A maintained, visionOS-native linkage path to FFmpeg 8.1.
- Direct 2D-to-3D frame conversion support through VisionOS2Dto3D.
- Clean separation between legacy iOS/tvOS demo binaries and visionOS runtime.
- A base you can extend for your own decoder/player pipeline (for example, AVSampleBufferDisplayLayer or RealityKit renderer paths).

The `visionOS` package includes `VisionStereoPipeline`, a high-level wrapper that
combines FFmpeg decode output (`CVPixelBuffer`) with 2D-to-3D processing and
host-time enqueuing via `AVSampleBufferVideoRenderer`.

It also includes `VisionStereoAssetPlayer`, a file-based player that uses
`AVAssetReader` to decode frames, runs them through the 2D-to-3D pipeline, and
publishes frames via `AVSampleBufferVideoRenderer` for visionOS presentation.

Current visionOS player controls include play, pause/resume, stop, seek,
playback-rate control, and callback hooks for state and playback-time updates.

###Note
- Now AVPlayer framework is able to play high resolution videos by using hardware accelerator feature embedded in iPhone/iPad even for MKV or AVI in H264, but this feature requires arm64, iOS 8 or later devices.
 
###Compile Requirements

 - ARC
 - XCode 7.x & iOS SDK 9.x

###Deploy Requirements

 - ARMv7, ARMv7s, ARM64 and x86-64 architectures
 - iOS version: Deploy target iOS 7.0 or later
 - Apple TV OS version: Deploy target 9.0 or later

###Features

 - ARC support.
 - Bitcode support.
 - armv7, armv7s, arm64 and x86-64 support.
 - file, ftp, http, https, rtsp, rtmp and most of FFmpeg protocols support.
 - Hardware decoder support for H264 format. (iOS 8 or later, only available on iOS platform.)
 - Rich options of ffmpeg library support.
 - Disable audio or video stream.
 - Parse audio and video duration, frame size infos.
 - Grab video thumbnails.
 - Real-time bit & frame rate and network buffering progress calculation.
 - Query current playback time info.
 - Playback speed control.
 - Brightness, contrast and saturation control.
 - Background audio, video playback support.
 - Full screen mode support.
 - Aspect ratio option support.
 - System volume control.
 - Play from a specified time position.
 - Play, pause, resume, stop, fast forward, fast backward, seek position actions support.
 - Audio session interruption handler support
 - Delegate support, you can get notification when state, playback progress, buffering progress changed and enter/exit full screen mode.
 - Save, Restore playback progress support (block style).
 - Multiple audio, subtitle streams support.
 - SRT, ASS, SSA, SMI external subtitle formats support.
 - Embedded subtitle formats support.
 - Custom subtitle font, text color.

###Dolby License

DO NOT use dolby tech in your iOS app unless you have a dolby license.
Dolby Digital(AC3), Dolby Digital Plus(E-AC3) and Dolby TrueHD(MLP).

###DEMO Screeshots
[![](https://dl.dropboxusercontent.com/u/87201024/avplayer/1.png)](https://dl.dropboxusercontent.com/u/87201024/avplayer/1.png)
[![](https://dl.dropboxusercontent.com/u/87201024/avplayer/2.png)](https://dl.dropboxusercontent.com/u/87201024/avplayer/2.png)
[![](https://dl.dropboxusercontent.com/u/87201024/avplayer/3.png)](https://dl.dropboxusercontent.com/u/87201024/avplayer/3.png)
[![](https://dl.dropboxusercontent.com/u/87201024/avplayer/6.png)](https://dl.dropboxusercontent.com/u/87201024/avplayer/6.png)
[![](https://dl.dropboxusercontent.com/u/87201024/avplayer/4.png)](https://dl.dropboxusercontent.com/u/87201024/avplayer/4.png)
[![](https://dl.dropboxusercontent.com/u/87201024/avplayer/5.png)](https://dl.dropboxusercontent.com/u/87201024/avplayer/5.png)

###Contact us

 - Twitter: @imoreapps
 - Email: imoreapps@gmail.com
