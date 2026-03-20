// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ZeroWhisper",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "ZeroWhisper",
            path: "ZeroWhisper",
            exclude: ["Info.plist", "ZeroWhisper.entitlements"],
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
