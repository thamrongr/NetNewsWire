// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "SwiftSoup",
	platforms: [.macOS(.v13), .iOS(.v17)],
    products: [
        .library(
			name: "SwiftSoup",
			type: .dynamic,
			targets: ["SwiftSoup"]
		)
    ],
    targets: [
        .target(
            name: "SwiftSoup"),
    ]
)
