import PackageDescription

let package = Package(
    name: "EasyAPNS",
    dependencies: [
        .Package(url: "https://github.com/osjup/libc", majorVersion: 0, minor: 1),
        .Package(url: "https://github.com/osjup/Perfect-libcurl.git", majorVersion: 0, minor: 5),
        .Package(url: "https://github.com/Zewo/JSON.git", majorVersion: 0, minor: 9)

    ],
    exclude: [
        "Example"
    ],
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
    ]
)
