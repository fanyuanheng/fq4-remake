// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FQ4Wrapper",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "FQ4Wrapper", targets: ["FQ4Wrapper"]),
    ],
    targets: [
        .executableTarget(
            name: "FQ4Wrapper",
            path: "Sources/FQ4Wrapper"
        ),
        .testTarget(
            name: "FQ4WrapperTests",
            dependencies: ["FQ4Wrapper"],
            path: "Tests/FQ4WrapperTests"
        ),
    ]
)
