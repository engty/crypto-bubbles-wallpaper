// swift-tools-version: 6.0
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
    swiftLanguageModes: [.v5]
)
