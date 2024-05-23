// swift-tools-version: 5.9
import PackageDescription

#if TUIST
    import ProjectDescription
    import ProjectDescriptionHelpers

    let packageSettings = PackageSettings(
        productTypes: [
            "ComposableArchitecture": .framework
        ],
        baseSettings: .settings(configurations: [
            .debug(name: "Debug"),
            .release(name: "Staging"),
            .release(name: "Release")
        ])
    )

#endif

let package = Package(
    name: "Dependencies",
    dependencies: [
        .package(
            url: "https://github.com/firebase/firebase-ios-sdk.git",
            exact: .init(10, 26, 0)
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture.git",
            exact: .init(1, 9, 3)
        )
    ]
)
