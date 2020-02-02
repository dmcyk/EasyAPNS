// swift-tools-version:5.1
import PackageDescription

let package = Package(
  name: "EasyAPNS",
  platforms: [.macOS(.v10_14)],
  products: [
    .library(name: "EasyAPNS", type: .dynamic, targets: ["EasyAPNS"]),
    .executable(name: "EasyAPNSExample", targets: ["EasyAPNSExample"]),
  ],
  dependencies: [
    // 4.0 beta
    .package(
      url: "https://github.com/vapor/open-crypto.git",
      .revision("90c49bc68ee6d992fa13cf84ca8fc54b97eaf4cc")
    ),
    .package(
      url: "https://github.com/dmcyk/SwiftyCurl.git",
      .upToNextMajor(from: "1.0.0")
    ),
  ],
  targets: [
    .target(name: "libc"),
    // bridge more OpenSSL APIs
    .systemLibrary(
      name: "COpenSSLBridge",
      pkgConfig: "openssl",
      providers: [.apt(["openssl libssl-dev"]), .brew(["openssl@1.1"])]
    ),
    .target(
      name: "EasyAPNS",
      dependencies: [
        "OpenCrypto", "SwiftyCurl", "libc", "COpenSSLBridge"
      ]
    ), .target(name: "EasyAPNSExample", dependencies: ["EasyAPNS"]),
  ]
)
