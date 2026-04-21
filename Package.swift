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
        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.7.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.0.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
    ],
    targets: [
        .target(
            name: "TrackGradeCore",
            dependencies: [
                "ColorBoxOpenAPI",
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
            ],
            path: "Core",
            exclude: [
                "ColorBoxAPI/GeneratedClient",
            ]
        ),
        .target(
            name: "ColorBoxOpenAPI",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
            ],
            path: "Core/ColorBoxAPI/GeneratedClient",
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator"),
            ]
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
            dependencies: [
                "TrackGradeCore",
                "ColorBoxOpenAPI",
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
            ],
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
