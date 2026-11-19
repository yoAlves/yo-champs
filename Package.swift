// swift-tools-version: 6.0
import PackageDescription

/// The macOS targets are declared only on Apple platforms so the Core module
/// keeps building (and testing) on Linux CI without AppKit/SwiftUI.
var products: [Product] = [
    .library(name: "YoChampsCore", targets: ["YoChampsCore"]),
    .library(name: "YoChampsProviders", targets: ["YoChampsProviders"]),
]

var targets: [Target] = [
    .target(name: "YoChampsCore"),
    .target(name: "YoChampsProviders", dependencies: ["YoChampsCore"]),
]

#if os(macOS)
    products += [
        .library(name: "YoChampsNetwork", targets: ["YoChampsNetwork"]),
        .executable(name: "YoChampsMac", targets: ["YoChampsMac"]),
        .executable(name: "YoChampsMascotValidator", targets: ["YoChampsMascotValidator"]),
        .executable(name: "YoChampsProviderCheck", targets: ["YoChampsProviderCheck"]),
    ]

    targets += [
        .target(
            name: "YoChampsNetwork",
            dependencies: ["YoChampsCore", "YoChampsProviders"]
        ),
        .executableTarget(
            name: "YoChampsMac",
            dependencies: [
                "YoChampsCore",
                "YoChampsProviders",
                "YoChampsNetwork",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ]
        ),
        .executableTarget(name: "YoChampsMascotValidator", dependencies: ["YoChampsCore"]),
        .executableTarget(
            name: "YoChampsProviderCheck",
            dependencies: ["YoChampsCore", "YoChampsProviders", "YoChampsNetwork"]
        ),
    ]

    targets.append(
        .testTarget(
            name: "YoChampsMacTests",
            dependencies: [
                "YoChampsMac",
                "YoChampsCore",
                .product(name: "Testing", package: "swift-testing"),
            ]
        )
    )

    targets.append(
        .testTarget(
            name: "YoChampsNetworkTests",
            dependencies: [
                "YoChampsNetwork",
                .product(name: "Testing", package: "swift-testing"),
            ]
        )
    )
#endif

targets.append(
    .testTarget(
        name: "YoChampsCoreTests",
        dependencies: [
            "YoChampsCore",
            // Command Line Tools ship a Testing.framework without
            // lib_TestingInterop; the official package builds everywhere.
            .product(name: "Testing", package: "swift-testing"),
        ]
    )
)

targets.append(
    .testTarget(
        name: "YoChampsProvidersTests",
        dependencies: [
            "YoChampsProviders",
            "YoChampsCore",
            .product(name: "Testing", package: "swift-testing"),
        ]
    )
)

let package = Package(
    name: "YoChamps",
    platforms: [.macOS(.v14)],
    products: products,
    dependencies: [
        // 6.3+ links the toolchain-only `_TestingInterop` library, which
        // Command Line Tools do not ship. 6.2.4 has no such link and still
        // integrates with SwiftPM's native test runner.
        .package(url: "https://github.com/swiftlang/swift-testing.git", exact: "6.2.4"),
        // Latest 1.x: swift-tools 5.9 and macOS 10.13 minimum, both below this
        // package's Swift 6.0 tools version and macOS 14 deployment target.
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", exact: "1.17.0"),
    ],
    targets: targets
)
