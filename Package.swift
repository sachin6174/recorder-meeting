// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "InterviewRecorder",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "InterviewRecorder", targets: ["InterviewRecorder"])
    ],
    targets: [
        .executableTarget(
            name: "InterviewRecorder",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "InterviewRecorderTests",
            dependencies: ["InterviewRecorder"]
        )
    ],
    swiftLanguageModes: [.v5]
)
