// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DeskPetMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DeskPetMac", targets: ["DeskPetMac"])
    ],
    targets: [
        .target(
            name: "DeskPetCore",
            path: "Sources/DeskPetCore"
        ),
        .executableTarget(
            name: "DeskPetMac",
            dependencies: ["DeskPetCore"],
            path: "Sources/DeskPetMac"
        ),
        .testTarget(
            name: "DeskPetCoreTests",
            dependencies: ["DeskPetCore"],
            path: "Tests/DeskPetCoreTests"
        )
    ]
)
