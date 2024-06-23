// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SPARQLSyntax",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SPARQLSyntax",
            targets: ["SPARQLSyntax"]),
        .executable(
        	name: "sparqllint",
        	targets: ["sparqllint"]),
        .executable(
        	name: "sparql-parser",
        	targets: ["sparql-parser"]),
    ],
    dependencies: [
		.package(url: "https://github.com/kasei/swift-serd.git", .upToNextMinor(from: "0.0.4"))
    ],
    targets: [
        .executableTarget(
            name: "sparqllint",
            dependencies: ["SPARQLSyntax"]
        ),
        .executableTarget(
            name: "sparql-parser",
            dependencies: ["SPARQLSyntax"]
        ),
        .target(
            name: "SPARQLSyntax",
            dependencies: [
            	.product(name: "serd", package: "swift-serd")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "SPARQLSyntaxTests",
            dependencies: ["SPARQLSyntax"]
        ),
    ]
)
