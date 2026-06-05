// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClickGuard",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "ClickGuardCore",
            path: "ClickGuardCore"
        ),
        .executableTarget(
            name: "ClickGuard",
            dependencies: ["ClickGuardCore"],
            path: "ClickGuard",
            exclude: ["Info.plist", "Resources"],
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("CoreGraphics"),
            ]
        ),
        .executableTarget(
            name: "StressTest",
            dependencies: ["ClickGuardCore"],
            path: "StressTest"
        ),
    ]
)
