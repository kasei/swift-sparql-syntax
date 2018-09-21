// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SPARQLSyntax",
    products: [
        .library(
            name: "SPARQLSyntax",
            targets: ["SPARQLSyntax"]),
    ],
    dependencies: [
		.package(url: "https://github.com/kasei/swift-serd.git", from: "0.0.3"),
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
            dependencies: ["serd"]
        ),
        .testTarget(
            name: "SPARQLSyntaxTests",
            dependencies: ["SPARQLSyntax"]
        ),
    ]
)
