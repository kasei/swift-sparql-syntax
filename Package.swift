// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SPARQLParser",
    products: [
        .library(
            name: "SPARQLParser",
            targets: ["SPARQLParser"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "sparql-parser",
            dependencies: ["SPARQLParser"]
        ),
        .target(
            name: "SPARQLParser",
            dependencies: []),
        .testTarget(
            name: "SPARQLParserTests",
            dependencies: ["SPARQLParser"]),
    ]
)
