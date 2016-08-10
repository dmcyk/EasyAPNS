import PackageDescription

let package = Package(
    name: "EasyAPNS",
    targets: [
        Target(
            name: "EasyAPNS",
			dependencies: [
				.Target(name: "libc")
			]
        ),
        Target(
            name: "Example",
            dependencies: [
                .Target(name: "EasyAPNS")
            ]
        )
    ],
    dependencies: [
        .Package(url: "https://github.com/osjup/Perfect-libcurl.git", majorVersion: 0, minor: 5),
        .Package(url: "https://github.com/Zewo/JSON.git", majorVersion: 0, minor: 9)

    ],
    exclude: [
        "Example"
    ]
)
