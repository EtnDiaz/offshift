// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OffshiftCompanion",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OffshiftCompanionCore", targets: ["OffshiftCompanionCore"]),
        .executable(name: "OffshiftCompanion", targets: ["OffshiftCompanion"])
    ],
    targets: [
        .target(name: "OffshiftCompanionCore"),
        .executableTarget(
            name: "OffshiftCompanion",
            dependencies: ["OffshiftCompanionCore"],
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "OffshiftCompanionCoreTests",
            dependencies: ["OffshiftCompanionCore"]
        )
    ]
)
