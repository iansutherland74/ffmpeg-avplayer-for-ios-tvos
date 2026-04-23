import Foundation

#if os(visionOS)
import avcodec
import avformat
import avfilter
import avutil
import swresample
import swscale
#endif

public enum FFmpegBridge {
    /// Returns libavformat version from the linked FFmpeg runtime.
    public static func avformatVersion() -> UInt32 {
        #if os(visionOS)
        return avformat_version()
        #else
        return 0
        #endif
    }

    /// Returns libavcodec version from the linked FFmpeg runtime.
    public static func avcodecVersion() -> UInt32 {
        #if os(visionOS)
        return avcodec_version()
        #else
        return 0
        #endif
    }
}
