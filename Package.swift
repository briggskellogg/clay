// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClayCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "ClayCore", targets: ["ClayCore"])],
    targets: [
        .target(name: "ClayCore"),
        .testTarget(name: "ClayCoreTests", dependencies: ["ClayCore"])
    ],
    swiftLanguageVersions: [.v5]
)
