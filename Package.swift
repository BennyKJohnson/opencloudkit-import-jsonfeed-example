import PackageDescription

let package = Package(
    name: "flame-server",
    dependencies: [
        .Package(url: "https://github.com/vapor/vapor.git", majorVersion: 1, minor: 1),
        .Package(url: "https://github.com/BennyKJohnson/OpenCloudKit.git", majorVersion: 0, minor: 5)

    ],
    exclude: [
        "Config",
        "Database",
        "Localization",
        "Public",
        "Resources",
        "Tests",
    ]
)

