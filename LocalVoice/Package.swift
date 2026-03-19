// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LocalVoice",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "LocalVoice",
            path: "LocalVoice",
            exclude: ["Info.plist", "LocalVoice.entitlements"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
            ]
        )
    ]
)
