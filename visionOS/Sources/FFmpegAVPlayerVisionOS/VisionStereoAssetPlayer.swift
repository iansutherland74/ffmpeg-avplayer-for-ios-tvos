import Foundation
import AVFoundation
import CoreMedia
import CoreML

/// Errors produced by `VisionStereoAssetPlayer`.
public enum VisionStereoAssetPlayerError: Error, LocalizedError {
    case noVideoTrack
    case cannotAddOutput
    case startReadingFailed(String)
    case readerFailed(String)

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
        }
    }
}

/// A simple file-based visionOS player that runs 2D frames through the
/// FFmpegAVPlayerVisionOS stereo pipeline and enqueues them for display.
public final class VisionStereoAssetPlayer {
    public let renderer: AVSampleBufferVideoRenderer
    public var onError: ((Error) -> Void)?

    private let pipeline: VisionStereoPipeline
    private let readerStateQueue = DispatchQueue(label: "com.ffmpegavplayer.vision.reader")
    private var reader: AVAssetReader?
    private var playbackTask: Task<Void, Never>?

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

    public func play(url: URL) {
        stop()

        playbackTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                try await self.playInternal(url: url)
            } catch {
                await MainActor.run {
                    self.onError?(error)
                }
            }
        }
    }

    public func stop() {
        playbackTask?.cancel()
        playbackTask = nil

        readerStateQueue.sync {
            reader?.cancelReading()
            reader = nil
        }

        pipeline.flushForReattach()
    }

    private func playInternal(url: URL) async throws {
        let asset = AVURLAsset(url: url)
        guard let videoTrack = try await asset.loadTracks(withMediaCharacteristic: .visual).first else {
            throw VisionStereoAssetPlayerError.noVideoTrack
        }

        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        let defaultFrameDuration = Self.defaultDuration(fromNominalFrameRate: nominalFrameRate)

        let reader = try AVAssetReader(asset: asset)
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

            try await Self.pacePlayback(currentPTS: pts, lastPTS: lastPTS, defaultDuration: frameDuration)
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
        defaultDuration: CMTime
    ) async throws {
        var sleepSeconds = defaultDuration.seconds

        if currentPTS.isValid, lastPTS.isValid {
            let delta = CMTimeSubtract(currentPTS, lastPTS)
            if delta.isValid {
                sleepSeconds = delta.seconds
            }
        }

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
}