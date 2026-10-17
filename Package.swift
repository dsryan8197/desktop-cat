// swift-tools-version:6.0
// Build the app with ./build.sh (wraps `swift build` into DesktopCat.app).
// Run the tests with `swift test`.
import PackageDescription

let package = Package(
    name: "DesktopCat",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "DesktopCat", path: "Sources/DesktopCat"),
        .testTarget(name: "DesktopCatTests", dependencies: ["DesktopCat"], path: "Tests/DesktopCatTests"),
    ],
    swiftLanguageModes: [.v5]
)
