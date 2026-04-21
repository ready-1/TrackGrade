// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TrackGradeCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "TrackGradeCore",
            targets: ["TrackGradeCore"]
        ),
        .executable(
            name: "MockColorBox",
            targets: ["MockColorBox"]
        ),
    ],
    targets: [
        .target(
            name: "TrackGradeCore",
            path: "Core"
        ),
        .executableTarget(
            name: "MockColorBox",
            dependencies: ["TrackGradeCore"],
            path: "MockServer"
        ),
        .testTarget(
            name: "TrackGradeCoreTests",
            dependencies: ["TrackGradeCore"],
            path: "Tests/UnitTests"
        ),
        .testTarget(
            name: "TrackGradeIntegrationTests",
            dependencies: ["TrackGradeCore"],
            path: "Tests/IntegrationTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
