// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MicroRIBs",
	platforms: [
		.iOS(.v15),
		.macOS(.v13)
	],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MicroRIBs",
            targets: ["MicroRIBs"]
        ),
    ],
	dependencies: [
		.package(url: "https://github.com/apple/swift-async-algorithms", from: "1.1.7")
	],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "MicroRIBs",
			dependencies: [
				.product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
			]
        ),
        .testTarget(
            name: "MicroRIBsTests",
            dependencies: ["MicroRIBs"]
        ),
    ],
	swiftLanguageModes: [.v6]
)
