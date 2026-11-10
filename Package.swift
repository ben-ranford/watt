// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Watt",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Watt", targets: ["Watt"]),
        .executable(name: "WattHelper", targets: ["WattHelper"]),
        .executable(name: "WattMaintenance", targets: ["WattMaintenance"]),
        .executable(name: "WattHelperInstaller", targets: ["WattHelperInstaller"])
    ],
    targets: [
        .executableTarget(
            name: "Watt",
            dependencies: ["WattHelperShared", "WattMaintenanceShared"],
            path: ".",
            exclude: [
                ".gitignore",
                "AGENTS.md",
                "DESIGN.md",
                "Package.swift",
                "SCREEN-BACKLOG.md",
                "Tests",
                "Resources",
                "Helper",
                "HelperShared",
                "HelperDaemon",
                "HelperInstaller",
                "Maintenance",
                "MaintenanceShared",
                "Watt.xcodeproj",
                "docs",
                "scripts"
            ],
            sources: ["App", "DesignSystem", "Features", "Models", "Services"]
        ),
        .target(name: "WattHelperShared", path: "HelperShared"),
        .target(name: "WattMaintenanceShared", dependencies: ["WattHelperShared"], path: "MaintenanceShared"),
        .target(name: "WattHelperRuntime", dependencies: ["WattHelperShared"], path: "Helper"),
        .executableTarget(name: "WattHelper", dependencies: ["WattHelperShared", "WattHelperRuntime"], path: "HelperDaemon"),
        .executableTarget(name: "WattMaintenance", dependencies: ["WattMaintenanceShared", "WattHelperShared"], path: "Maintenance"),
        .executableTarget(name: "WattHelperInstaller", dependencies: ["WattMaintenanceShared", "WattHelperShared"], path: "HelperInstaller"),
        .target(name: "WattFixtures", path: "Tests/Fixtures"),
        .testTarget(
            name: "WattTests",
            dependencies: ["Watt", "WattFixtures", "WattHelperShared", "WattHelperRuntime", "WattMaintenanceShared", "WattHelperInstaller"],
            path: "Tests/WattTests"
        )
    ]
)
