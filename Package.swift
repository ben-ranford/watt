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
                "Resources",
                "Watt.xcodeproj",
                "docs",
                "scripts"
            ],
            sources: ["App", "DesignSystem", "Features", "Models", "Services"]
        ),
        .target(name: "WattFixtures", path: "Tests/Fixtures"),
        .testTarget(
            name: "WattTests",
            dependencies: ["Watt", "WattFixtures"],
            path: "Tests/WattTests"
        )
    ]
)
