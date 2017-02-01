import PackageDescription

let package = Package(
    name: "EasyAPNS",
    targets: [
        Target(
            name: "EasyAPNS"
        ),
        Target(
            name: "Example",
            dependencies: [
                .Target(name: "EasyAPNS")
            ]
        )
    ],
    dependencies: [
        .Package(url: "https://github.com/vdka/JSON.git", majorVersion: 0, minor: 16),
        .Package(url: "https://github.com/vapor/clibressl.git", majorVersion: 1, minor: 0),
        .Package(url: "https://github.com/vapor/crypto.git", majorVersion: 1, minor: 0),
        .Package(url: "https://github.com/dmcyk/SwiftyCurl.git", majorVersion: 0, minor: 6)


    ],
    exclude: [
        "Example"
    ]
)
