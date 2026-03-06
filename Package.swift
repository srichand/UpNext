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
    targets: [
        .target(
            name: "UpNextCore",
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
