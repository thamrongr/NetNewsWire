// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "ArticleExtractor",
	platforms: [.macOS(.v13), .iOS(.v17)],
	products: [
		.library(
			name: "ArticleExtractor",
			type: .dynamic,
			targets: ["ArticleExtractor"]),
	],
	dependencies: [
		.package(path: "../Articles"),
		.package(path: "../RSParser"),
		.package(path: "../SwiftSoup"),
		.package(path: "../RSWeb"),
	],
	targets: [
		.target(
			name: "ArticleExtractor",
			dependencies: [
				"Articles",
				"RSParser",
				"SwiftSoup",
				"RSWeb",
			]),
	]
)
