// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Ghostax",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/Lakr233/libghostty-spm.git", from: "1.2.11")
    ],
    targets: [
        .executableTarget(
            name: "Ghostax",
            dependencies: [
                .product(name: "GhosttyTerminal", package: "libghostty-spm")
            ]
        ),
    ]
)
