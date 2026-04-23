import Foundation
import AVFoundation
import CoreMedia
import CoreML

public enum VisionStereoPlaybackState: Sendable {
    case idle
    case playing
    case paused
    case stopped
    case completed
    case failed
}

/// Errors produced by `VisionStereoAssetPlayer`.
public enum VisionStereoAssetPlayerError: Error, LocalizedError {
    case noVideoTrack
    case cannotAddOutput
    case startReadingFailed(String)
    case readerFailed(String)
    case noLoadedURLForSeek

    public var errorDescription: String? {
        switch self {
        case .noVideoTrack:
            return "No visual track found in asset"
        case .cannotAddOutput:
            return "Unable to add track output to AVAssetReader"
        case let .startReadingFailed(message):
            return "AVAssetReader failed to start: \(message)"
        case let .readerFailed(message):
            return "AVAssetReader failed during playback: \(message)"
        case .noLoadedURLForSeek:
            return "No current media URL is loaded for seek"
        }
    }
}

/// A simple file-based visionOS player that runs 2D frames through the
/// FFmpegAVPlayerVisionOS stereo pipeline and enqueues them for display.
public final class VisionStereoAssetPlayer {
    public let renderer: AVSampleBufferVideoRenderer
    public var onError: ((Error) -> Void)?
    public var onStateChanged: ((VisionStereoPlaybackState) -> Void)?
    public var onPlaybackTimeChanged: ((CMTime) -> Void)?

    private let pipeline: VisionStereoPipeline
    private let readerStateQueue = DispatchQueue(label: "com.ffmpegavplayer.vision.reader")
    private let controlStateQueue = DispatchQueue(label: "com.ffmpegavplayer.vision.controls")
    private var reader: AVAssetReader?
    private var playbackTask: Task<Void, Never>?
    private var currentURL: URL?
    private var currentState: VisionStereoPlaybackState = .idle
    private var isPaused = false
    private var playbackRate: Double = 1.0

    public init(
        model: MLModel,
        maxDisparity: CGFloat = 0.035,
        temporalSmoothing: Float = 0.7
    ) throws {
        self.pipeline = try VisionStereoPipeline(
            model: model,
            maxDisparity: maxDisparity,
            temporalSmoothing: temporalSmoothing
        )
        self.renderer = pipeline.renderer
    }

    public func updateMaxDisparity(_ value: CGFloat) {
        pipeline.updateMaxDisparity(value)
    }

    public func play(url: URL, startAt: CMTime = .zero) {
        stop()

        controlStateQueue.sync {
            currentURL = url
            isPaused = false
        }
        emitState(.playing)

        playbackTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                try await self.playInternal(url: url, startAt: startAt)
                await MainActor.run {
                    self.emitState(.completed)
                }
            } catch {
                await MainActor.run {
                    self.emitState(.failed)
                    self.onError?(error)
                }
            }
        }
    }

    public func pause() {
        controlStateQueue.sync {
            isPaused = true
        }
        emitState(.paused)
    }

    public func resume() {
        controlStateQueue.sync {
            isPaused = false
        }
        emitState(.playing)
    }

    public func setPlaybackRate(_ rate: Double) {
        controlStateQueue.sync {
            playbackRate = max(0.25, min(rate, 4.0))
        }
    }

    public func seek(to time: CMTime) throws {
        let url = controlStateQueue.sync { currentURL }
        guard let url else {
            throw VisionStereoAssetPlayerError.noLoadedURLForSeek
        }
        play(url: url, startAt: time)
    }

    public func stop() {
        playbackTask?.cancel()
        playbackTask = nil

        controlStateQueue.sync {
            isPaused = false
        }

        readerStateQueue.sync {
            reader?.cancelReading()
            reader = nil
        }

        pipeline.flushForReattach()
        emitState(.stopped)
    }

    private func playInternal(url: URL, startAt: CMTime) async throws {
        let asset = AVURLAsset(url: url)
        guard let videoTrack = try await asset.loadTracks(withMediaCharacteristic: .visual).first else {
            throw VisionStereoAssetPlayerError.noVideoTrack
        }

        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        let defaultFrameDuration = Self.defaultDuration(fromNominalFrameRate: nominalFrameRate)

        let reader = try AVAssetReader(asset: asset)
        if startAt.isValid, startAt > .zero {
            reader.timeRange = CMTimeRange(start: startAt, duration: .positiveInfinity)
        }
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]

        let output = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
        output.alwaysCopiesSampleData = false

        guard reader.canAdd(output) else {
            throw VisionStereoAssetPlayerError.cannotAddOutput
        }
        reader.add(output)

        guard reader.startReading() else {
            throw VisionStereoAssetPlayerError.startReadingFailed(reader.error?.localizedDescription ?? "unknown")
        }

        readerStateQueue.sync {
            self.reader = reader
        }

        var lastPTS: CMTime = .invalid

        while !Task.isCancelled {
            while controlStateQueue.sync(execute: { isPaused }) {
                try await Task.sleep(nanoseconds: 20_000_000)
                if Task.isCancelled {
                    break
                }
            }

            guard let sampleBuffer = output.copyNextSampleBuffer() else { break }
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { continue }

            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let duration = CMSampleBufferGetDuration(sampleBuffer)
            let frameDuration = (duration.isValid && duration != .zero) ? duration : defaultFrameDuration

            try pipeline.processAndEnqueue(
                pixelBuffer: imageBuffer,
                presentationTime: pts,
                duration: frameDuration
            )

            await MainActor.run {
                self.onPlaybackTimeChanged?(pts)
            }

            let activeRate = controlStateQueue.sync { playbackRate }

            try await Self.pacePlayback(
                currentPTS: pts,
                lastPTS: lastPTS,
                defaultDuration: frameDuration,
                playbackRate: activeRate
            )
            lastPTS = pts
        }

        readerStateQueue.sync {
            if self.reader === reader {
                self.reader = nil
            }
        }

        if reader.status == .failed {
            throw VisionStereoAssetPlayerError.readerFailed(reader.error?.localizedDescription ?? "unknown")
        }
    }

    private static func defaultDuration(fromNominalFrameRate fps: Float) -> CMTime {
        guard fps > 0 else {
            return CMTime(value: 1, timescale: 30)
        }
        let roundedFPS = max(1, Int32(fps.rounded()))
        return CMTime(value: 1, timescale: roundedFPS)
    }

    private static func pacePlayback(
        currentPTS: CMTime,
        lastPTS: CMTime,
        defaultDuration: CMTime,
        playbackRate: Double
    ) async throws {
        var sleepSeconds = defaultDuration.seconds

        if currentPTS.isValid, lastPTS.isValid {
            let delta = CMTimeSubtract(currentPTS, lastPTS)
            if delta.isValid {
                sleepSeconds = delta.seconds
            }
        }

        sleepSeconds = sleepSeconds / max(0.25, min(playbackRate, 4.0))

        guard sleepSeconds.isFinite, sleepSeconds > 0 else {
            return
        }

        // Clamp to keep cancellation responsive on sparse timestamps.
        let clamped = min(sleepSeconds, 0.25)
        let nanos = UInt64(clamped * 1_000_000_000)
        if nanos > 0 {
            try await Task.sleep(nanoseconds: nanos)
        }
    }

    @MainActor
    private func emitState(_ state: VisionStereoPlaybackState) {
        currentState = state
        onStateChanged?(state)
    }
}