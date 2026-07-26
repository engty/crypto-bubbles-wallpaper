// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CryptoBubblesWallpaper",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "CryptoBubblesWallpaper",
            targets: ["CryptoBubblesWallpaper"]
        )
    ],
    targets: [
        .executableTarget(
            name: "CryptoBubblesWallpaper",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("WebKit")
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)
