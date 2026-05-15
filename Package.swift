// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Tocco",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "Tocco", targets: ["Tocco"])
    ],
    targets: [
        .target(
            name: "Tocco",
            path: "Tocco",
            exclude: [],
            sources: [
                "App",
                "AR",
                "Rendering",
                "Sculpt",
                "Input",
                "UI",
                "Export",
                "Session",
                "Support"
            ]
        ),
        .testTarget(
            name: "ToccoTests",
            dependencies: ["Tocco"],
            path: "ToccoTests"
        )
    ]
)
