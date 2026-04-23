import Foundation

#if os(visionOS)
import avcodec
import avformat
#endif

/// Runtime capability inspection helpers backed by the linked FFmpeg libraries.
public enum FFmpegRuntimeCapabilities {
    public static func inputProtocols() -> [String] {
        #if os(visionOS)
        avformat_network_init()
        var opaque: UnsafeMutableRawPointer?
        var protocols: [String] = []
        while let ptr = avio_enum_protocols(&opaque, 0) {
            protocols.append(String(cString: ptr))
        }
        return protocols.sorted()
        #else
        return []
        #endif
    }

    public static func outputProtocols() -> [String] {
        #if os(visionOS)
        avformat_network_init()
        var opaque: UnsafeMutableRawPointer?
        var protocols: [String] = []
        while let ptr = avio_enum_protocols(&opaque, 1) {
            protocols.append(String(cString: ptr))
        }
        return protocols.sorted()
        #else
        return []
        #endif
    }

    public static func decoders() -> [String] {
        #if os(visionOS)
        var opaque: UnsafeMutableRawPointer?
        var result: [String] = []
        while let codec = av_codec_iterate(&opaque) {
            guard av_codec_is_decoder(codec) != 0, let name = codec.pointee.name else {
                continue
            }
            result.append(String(cString: name))
        }
        return result.sorted()
        #else
        return []
        #endif
    }

    public static func supportsInputProtocol(_ name: String) -> Bool {
        inputProtocols().contains(name)
    }

    public static func supportsDecoder(_ name: String) -> Bool {
        decoders().contains(name)
    }

    public static func supportsDolbyFamily() -> (ac3: Bool, eac3: Bool, truehd: Bool) {
        let all = Set(decoders())
        return (
            ac3: all.contains("ac3"),
            eac3: all.contains("eac3"),
            truehd: all.contains("truehd")
        )
    }
}
