// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SPARQLSyntax",
    platforms: [.macOS(.v10_15)],
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
		.package(name: "Cserd", url: "https://github.com/kasei/swift-serd.git", .upToNextMinor(from: "0.0.4"))
    ],
    targets: [
        .target(
            name: "sparqllint",
            dependencies: ["SPARQLSyntax"]
        ),
        .target(
            name: "sparql-parser",
            dependencies: ["SPARQLSyntax"]
        ),
        .target(
            name: "SPARQLSyntax",
            dependencies: [
            	.product(name: "serd", package: "Cserd")
            ]
        ),
        .testTarget(
            name: "SPARQLSyntaxTests",
            dependencies: ["SPARQLSyntax"]
        ),
    ]
)
