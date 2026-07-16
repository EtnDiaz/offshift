// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OffshiftCompanion",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OffshiftCompanionCore", targets: ["OffshiftCompanionCore"])
    ],
    targets: [
        .target(name: "OffshiftCompanionCore"),
        .testTarget(
            name: "OffshiftCompanionCoreTests",
            dependencies: ["OffshiftCompanionCore"]
        )
    ]
)
