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
        // Pure ObjC target: all ObjC sources
        .target(
            name: "ZDMediatorObjC",
            path: "Sources/Classes/ObjC",
            publicHeadersPath: "Public",
            cSettings: [
                .headerSearchPath("Public"),
                .headerSearchPath("Tools"),
                .headerSearchPath("Private"),
            ]
        ),
        // Pure Swift target: all Swift sources + resource
        .target(
            name: "ZDMediator",
            dependencies: ["ZDMediatorObjC"],
            path: "Sources",
            exclude: [
                "Classes/ObjC",
            ],
            sources: [
                "Classes/Swift",
            ],
            resources: [.process("Resource/PrivacyInfo.xcprivacy")],
            swiftSettings: [
                .enableExperimentalFeature("SymbolLinkageMarkers"),
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "ZDMediatorTests",
            dependencies: ["ZDMediator"],
            path: "Tests/ZDMediatorTests"
        ),
    ]
)
