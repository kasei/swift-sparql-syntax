// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SPARQLSyntax",
    products: [
        .library(
            name: "SPARQLSyntax",
            targets: ["SPARQLSyntax"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "sparql-parser",
            dependencies: ["SPARQLSyntax"]
        ),
        .target(
            name: "SPARQLSyntax",
            dependencies: []),
        .testTarget(
            name: "SPARQLSyntaxTests",
            dependencies: ["SPARQLSyntax"]),
    ]
)
