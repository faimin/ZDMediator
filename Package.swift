// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ZDMediator",
    platforms: [
        .iOS(.v10),
        .macOS(.v10_12)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ZDMediator",
            targets: ["ZDMediator"]
        )
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ZDMediator",
            path: "Sources",
            resources: [.process("Resource/PrivacyInfo.xcprivacy")],
            publicHeadersPath: "Classes",
            cSettings: [
                .headerSearchPath("Classes"),
                .headerSearchPath("Classes/Invoke"),
                .headerSearchPath("Classes/Private")
            ]
        )
    ]
)
