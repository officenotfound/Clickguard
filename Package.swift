// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClickGuard",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ClickGuard",
            path: "ClickGuard",
            exclude: ["Info.plist"],
linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("CoreGraphics"),
            ]
        )
    ]
)
