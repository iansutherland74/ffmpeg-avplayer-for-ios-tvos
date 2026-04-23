import Foundation
import AVFoundation
import CoreMedia
import CoreML
import VisionOS2Dto3D

/// High-level bridge that combines FFmpeg-backed decode pipelines with
/// VisionOS2Dto3D stereo frame processing and host-time renderer enqueue.
public final class VisionStereoPipeline {
    public let renderer: AVSampleBufferVideoRenderer

    private let frameProcessor: StereoFrameProcessor
    private let sampleBufferBridge: StereoSampleBufferBridge

    public init(
        model: MLModel,
        maxDisparity: CGFloat = 0.035,
        temporalSmoothing: Float = 0.7
    ) throws {
        self.frameProcessor = try StereoFrameProcessor(
            model: model,
            maxDisparity: maxDisparity,
            temporalSmoothing: temporalSmoothing
        )
        self.sampleBufferBridge = StereoSampleBufferBridge()
        self.renderer = sampleBufferBridge.renderer
    }

    public func updateMaxDisparity(_ value: CGFloat) {
        frameProcessor.updateMaxDisparity(value)
    }

    public func flushForReattach() {
        sampleBufferBridge.flushForReattach()
    }

    /// Processes one 2D frame into SBS stereo and enqueues it for display.
    ///
    /// - Parameters:
    ///   - pixelBuffer: Input 2D frame.
    ///   - presentationTime: Source timeline timestamp.
    ///   - duration: Optional frame duration for output pacing.
    public func processAndEnqueue(
        pixelBuffer: CVPixelBuffer,
        presentationTime: CMTime,
        duration: CMTime = .invalid
    ) throws {
        let stereoFrame = try frameProcessor.process(pixelBuffer: pixelBuffer)
        try sampleBufferBridge.enqueue(
            pixelBuffer: stereoFrame.stereoPixelBuffer,
            at: presentationTime,
            duration: duration
        )
    }
}
