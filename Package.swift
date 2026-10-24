// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Levers",
    platforms: [.macOS(.v26)],  // Liquid Glass (.glassEffect) is macOS 26+
    targets: [
        .executableTarget(
            name: "Levers",
            path: "Sources/Levers",
            linkerSettings: [.linkedFramework("IOKit")]
        )
    ]
)
