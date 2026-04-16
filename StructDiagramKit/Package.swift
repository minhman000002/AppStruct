// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "StructDiagramKit",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "CoreLibrary",
            targets: ["CoreLibrary"]
        ),
        .executable(
            name: "diagram-cli",
            targets: ["DiagramCLI"]
        ),
        .plugin(
            name: "DiagramPlugin",
            targets: ["DiagramPlugin"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        // MARK: - Core Analysis Library
        .target(
            name: "CoreLibrary",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),

        // MARK: - CLI Executable
        .executableTarget(
            name: "DiagramCLI",
            dependencies: [
                "CoreLibrary",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),

        // MARK: - Xcode Command Plugin
        .plugin(
            name: "DiagramPlugin",
            capability: .command(
                intent: .custom(
                    verb: "generate-diagram",
                    description: "Generate a Mermaid class diagram from Swift source files and optionally update README.md"
                ),
                permissions: [
                    .writeToPackageDirectory(
                        reason: "Write the generated Mermaid diagram into README.md or an output file."
                    ),
                ]
            ),
            dependencies: [
                .target(name: "DiagramCLI"),
            ]
        ),

        // MARK: - Tests
        .testTarget(
            name: "CoreLibraryTests",
            dependencies: ["CoreLibrary"]
        ),
    ]
)
