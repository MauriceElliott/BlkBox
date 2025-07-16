// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BlkBox",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "blkbox",
            targets: ["BlkBox"]
        ),
        .library(
            name: "BlkBoxLib",
            targets: ["BlkBoxLib"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
        .package(url: "https://github.com/onevcat/Rainbow", from: "4.0.0"),
        .package(url: "https://github.com/jpsim/Yams", from: "5.0.0"),
        .package(url: "https://github.com/scottrhoyt/SwiftyTextTable", from: "0.9.0")
    ],
    targets: [
        .executableTarget(
            name: "BlkBox",
            dependencies: [
                "BlkBoxLib",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "Rainbow"
            ]
        ),
        .target(
            name: "BlkBoxLib",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "Rainbow",
                "Yams",
                "SwiftyTextTable"
            ]
        ),
        .testTarget(
            name: "BlkBoxTests",
            dependencies: ["BlkBoxLib"]
        )
    ]
)
