import PackageDescription

let package = Package(
    name: "EasyAPNS",
    targets: [
        Target(
            name: "EasyAPNS"
        ),
        Target(
            name: "EasyAPNSExample",
            dependencies: [
                .Target(name: "EasyAPNS")
            ]
        )
    ],
    dependencies: [
        .Package(url: "https://github.com/vdka/JSON.git", majorVersion: 0, minor: 16),
        .Package(url: "https://github.com/vapor/crypto.git", majorVersion: 2, minor: 1),
        .Package(url: "https://github.com/dmcyk/SwiftyCurl.git", majorVersion: 0)
    ],
    exclude: [
        "EasyAPNSExample"
    ]
)
