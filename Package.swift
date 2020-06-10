// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Interplate",
    products: [
        .library(name: "Interplate", targets: ["Interplate"])
    ],
    dependencies: [
        .package(url: "https://github.com/ilyapuchka/common-parsers.git", .revision("32ae19987d03a4fbd7c20e48f44f1725ea277852"))
    ],
    targets: [
        .target(name: "Interplate", dependencies: ["CommonParsers"]),
        .testTarget(name: "InterplateTests", dependencies: ["Interplate"])
    ]
)
