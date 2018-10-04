// swift-tools-version:4.2
import PackageDescription

let package = Package(
    name: "slash",
    products: [.executable(name: "slash", targets: ["slash"])],
    targets: [.target(name:  "slash", path: "Sources")]
)
