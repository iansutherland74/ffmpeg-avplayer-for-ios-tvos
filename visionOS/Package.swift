// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FFmpegAVPlayerVisionOS",
    platforms: [
        .custom("xros", versionString: "2.0")
    ],
    products: [
        .library(
            name: "FFmpegAVPlayerVisionOS",
            targets: ["FFmpegAVPlayerVisionOS"]
        )
    ],
    dependencies: [
        .package(path: "../../ffmpeg-kit-8.1/visionos-2d-to-3d")
    ],
    targets: [
        .binaryTarget(
            name: "avcodec",
            path: "FFmpegXCFrameworks/avcodec.xcframework"
        ),
        .binaryTarget(
            name: "avformat",
            path: "FFmpegXCFrameworks/avformat.xcframework"
        ),
        .binaryTarget(
            name: "avfilter",
            path: "FFmpegXCFrameworks/avfilter.xcframework"
        ),
        .binaryTarget(
            name: "avutil",
            path: "FFmpegXCFrameworks/avutil.xcframework"
        ),
        .binaryTarget(
            name: "swresample",
            path: "FFmpegXCFrameworks/swresample.xcframework"
        ),
        .binaryTarget(
            name: "swscale",
            path: "FFmpegXCFrameworks/swscale.xcframework"
        ),
        .target(
            name: "FFmpegAVPlayerVisionOS",
            dependencies: [
                .product(name: "VisionOS2Dto3D", package: "visionos-2d-to-3d"),
                "avcodec",
                "avformat",
                "avfilter",
                "avutil",
                "swresample",
                "swscale"
            ],
            path: "Sources/FFmpegAVPlayerVisionOS"
        )
    ]
)
