// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "UpNextCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "UpNextCore",
            targets: ["UpNextCore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.4")
    ],
    targets: [
        .target(
            name: "UpNextCore",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "UpNext",
            exclude: [
                "Resources",
                "UpNextApp.swift"
            ]
        ),
        .testTarget(
            name: "UpNextCoreTests",
            dependencies: ["UpNextCore"],
            path: "UpNextTests"
        )
    ]
)
