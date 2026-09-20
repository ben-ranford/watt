// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Watt",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Watt", targets: ["Watt"])
    ],
    targets: [
        .executableTarget(
            name: "Watt",
            path: ".",
            exclude: [
                ".gitignore",
                "AGENTS.md",
                "DESIGN.md",
                "Package.swift",
                "SCREEN-BACKLOG.md",
                "Tests",
                "Resources"
            ]
        ),
        .testTarget(
            name: "WattTests",
            dependencies: ["Watt"],
            path: "Tests/WattTests"
        )
    ]
)
