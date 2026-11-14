// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CartiRIBsConcurrency",
	platforms: [
		// `isolated deinit` needs the Swift 6.1 runtime shipped with iOS 18.4 / macOS 15.4.
		.iOS("18.4"),
		.macOS("15.4")
	],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "CartiRIBsConcurrency",
            targets: ["CartiRIBsConcurrency"]
        ),
    ],
	dependencies: [
		.package(url: "https://github.com/apple/swift-async-algorithms", exact: "1.0.4"),
		.package(url: "https://github.com/apple/swift-collections.git", exact: "1.1.4")
	],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "CartiRIBsConcurrency",
			dependencies: [
				.product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
				.product(name: "OrderedCollections", package: "swift-collections")
			]
        ),
        .testTarget(
            name: "CartiRIBsConcurrencyTests",
            dependencies: ["CartiRIBsConcurrency"]
        ),
    ],
	swiftLanguageModes: [.v6]
)
