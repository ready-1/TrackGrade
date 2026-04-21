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
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
    ],
    targets: [
        .target(
            name: "TrackGradeCore",
            path: "Core"
        ),
        .executableTarget(
            name: "MockColorBox",
            dependencies: [
                "TrackGradeCore",
                .product(name: "Vapor", package: "vapor"),
            ],
            path: "MockServer"
        ),
        .testTarget(
            name: "TrackGradeCoreTests",
            dependencies: ["TrackGradeCore"],
            path: "Tests/UnitTests"
        ),
        .testTarget(
            name: "TrackGradeIntegrationTests",
            dependencies: [
                "TrackGradeCore",
                "MockColorBox",
                .product(name: "Vapor", package: "vapor"),
            ],
            path: "Tests/IntegrationTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
