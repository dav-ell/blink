// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SCKBridge",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "SCKBridge",
            type: .static,
            targets: ["SCKBridge"]
        ),
    ],
    targets: [
        .target(
            name: "SCKBridge",
            dependencies: [],
            path: "Sources/SCKBridge",
            swiftSettings: [
                .unsafeFlags(["-emit-objc-header-path", ".build/SCKBridge-Swift.h"])
            ]
        ),
    ]
)


