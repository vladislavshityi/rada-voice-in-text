// swift-tools-version:6.0
import PackageDescription

let whisperLibrary = Context.packageDirectory + "/Vendor/whisper/lib"

let package = Package(
    name: "Rada",
    defaultLocalization: "ru",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Rada", targets: ["Rada"])
    ],
    targets: [
        .systemLibrary(name: "CWhisper", path: "Sources/CWhisper"),
        .target(
            name: "RadaKit",
            dependencies: ["CWhisper"],
            linkerSettings: [.unsafeFlags(["-L", whisperLibrary])]
        ),
        .executableTarget(name: "Rada", dependencies: ["RadaKit"]),
        .testTarget(name: "RadaKitTests", dependencies: ["RadaKit"], exclude: ["Fixtures"]),
    ]
)
