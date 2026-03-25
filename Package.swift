// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ZDMediator",
    platforms: [
        .iOS(.v13),
        .macOS(.v14),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "ZDMediator", targets: ["ZDMediator"]),
    ],
    targets: [
        .target(
            name: "ZDMediator",
            path: "Sources",
            resources: [.process("Resource/PrivacyInfo.xcprivacy")],
            publicHeadersPath: "Classes/ObjC/Public",
            cSettings: [
                .headerSearchPath("Classes/ObjC/Public"),
                .headerSearchPath("Classes/ObjC/Tools"),
                .headerSearchPath("Classes/ObjC/Private"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("SymbolLinkageMarkers"),
            ]
        ),
        .testTarget(
            name: "ZDMediatorTests",
            dependencies: ["ZDMediator"],
            path: "Tests/ZDMediatorTests"
        ),
    ]
)
