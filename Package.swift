// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "medo-delirio-api",
    platforms: [
       .macOS(.v13)
    ],
    products: [
        // The server's service runs .build/release/Run, so the binary keeps that name.
        .executable(name: "Run", targets: ["App"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.122.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.13.0"),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.9.0"),
        .package(url: "https://github.com/vapor/apns", from: "3.0.0"),
        // Imported directly to sign the broadcast push JWT, so declared rather than
        // left to arrive through APNS.
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "4.13.0"),
        .package(url: "https://github.com/nmdias/FeedKit.git", from: "9.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "APNS", package: "apns"),
                .product(name: "JWTKit", package: "jwt-kit"),
                .product(name: "FeedKit", package: "FeedKit")
            ]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .target(name: "App"),
                .product(name: "VaporTesting", package: "vapor"),
            ],
            // Read straight from disk via #filePath, see ElectionFixtures.
            exclude: ["Fixtures"]
        )
    ]
)
