// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "EasyAPNS",
    products: [
        .library(name: "EasyAPNS", type: .dynamic, targets: ["EasyAPNS"]),
        .executable(name: "EasyAPNSExample", targets: ["EasyAPNSExample"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vdka/JSON.git", .upToNextMajor(from: "0.16.3")),
        .package(url: "https://github.com/vapor/crypto.git", .upToNextMajor(from: "2.1.0")),
        .package(url: "https://github.com/dmcyk/SwiftyCurl.git", .upToNextMajor(from: "0.7.0")),
    ],
    targets: [
        .target(
            name: "EasyAPNS",
            dependencies: [
                "JSON", 
                "Crypto", 
                "SwiftyCurl"
            ]
        ),
        .target(
            name: "EasyAPNSExample",
            dependencies: [
                "EasyAPNS"
            ]
        ),
    ]
)
