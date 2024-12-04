import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "TheWebSnippet",
    organizationName: "Inova IT, d.o.o.",
    options: .options(
        disableBundleAccessors: true,
        disableSynthesizedResourceAccessors: true
    ),
    settings: .settings(
        configurations: [
            .debug( name: "Debug", xcconfig: .relativeToRoot("config/TWSDebug.xcconfig")),
            .debug( name: "Testing",settings: ["OTHER_SWIFT_FLAGS": "-DTESTING"], xcconfig: .relativeToRoot("config/TWSDebug.xcconfig")),
            .release(name: "Staging", xcconfig: .relativeToRoot("config/TWS.xcconfig")),
            .release(name: "Release", xcconfig: .relativeToRoot("config/TWS.xcconfig"))
        ]
    ),
    targets: [
        .target(
            name: "Template",
            destinations: .iOS,
            product: .app,
            bundleId: "com.inova.twsPlayground",
            deploymentTargets: .iOS(deploymentTarget()),
            infoPlist: .extendingDefault(with: infoPlistTemplate()),
            sources: ["Submodule_tws-cli-resources/iOS/App/Sources/**"],
            resources: ["Submodule_tws-cli-resources/iOS/App/Resources/**"],
            scripts: targetScriptsTemplate(),
            dependencies: [
                .target(name: "TWS")
//                .xcframework(path: "Submodule_tws-cli-resources/iOS/Frameworks/XCFrameworks/TWS.xcframework"),
//                .xcframework(path: "Submodule_tws-cli-resources/iOS/Frameworks/XCFrameworks/TWSModels.xcframework")
            ],
            settings: .settings(
                configurations: [
                    .debug(name: "Debug", settings: ["SWIFT_VERSION": "6.0"], xcconfig: .relativeToRoot("config/TWSDemo_dev.xcconfig")),
                    .release(name: "Staging", settings: ["SWIFT_VERSION": "6.0"], xcconfig: .relativeToRoot("config/TWSDemo_staging.xcconfig")),
                    .release(name: "Release", settings: ["SWIFT_VERSION": "6.0"], xcconfig: .relativeToRoot("config/TWSDemo_release.xcconfig"))
                ],
                defaultSettings: .recommended(excluding: [
                    "CODE_SIGN_IDENTITY",
                    "DEVELOPMENT_TEAM"
                ])
            )
        ),
        .target(
            name: "TWS",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.inova.tws",
            deploymentTargets: .iOS(deploymentTarget()),
            sources: ["TWS/Sources/**"],
            resources: ["TWS/Resources/**"],
            dependencies: [
                .external(name: "Mustache"),
                .target(name: "TWSCore"),
                .target(name: "TWSModels"),
                .target(name: "TWSLogger")
            ],
            settings: .settings(
                configurations: distributionConfigurations()
            )
        ),
        .target(
            name: "TWSCore",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "com.inova.twscore",
            deploymentTargets: .iOS(deploymentTarget()),
            sources: ["TWSCore/Sources/**"],
            dependencies: [
                .target(name: "TWSCommon"),
                .target(name: "TWSSnippets"),
                .target(name: "TWSSettings"),
                .target(name: "TWSUniversalLinks"),
                .target(name: "TWSLogger"),
                .target(name: "TWSFormatters")
            ],
            settings: .settings(
                configurations: internalConfigurations()
            )
        ),
        .target(
            name: "TWSSnippets",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "com.inova.twssnippets",
            deploymentTargets: .iOS(deploymentTarget()),
            sources: ["TWSSnippets/Sources/**"],
            dependencies: [
                .target(name: "TWSCommon"),
                .target(name: "TWSModels"),
                .target(name: "TWSSnippet"),
                .target(name: "TWSLogger")
            ],
            settings: .settings(
                configurations: internalConfigurations()
            )
        ),
        .target(
            name: "TWSFormatters",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "com.inova.twsformatters",
            deploymentTargets: .iOS(deploymentTarget()),
            sources: ["TWSFormatters/Sources/**"],
            settings: .settings(
                configurations: internalConfigurations()
            )
        ),
        .target(
            name: "TWSSnippetsTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.inova.twssnippetsTests",
            deploymentTargets: .iOS(deploymentTarget()),
            infoPlist: .default,
            sources: ["TWSSnippetsTests/Sources/**"],
            dependencies: [
                .target(name: "TWSSnippets")
            ],
            settings: .settings(
                configurations: testConfigurations()
            )
        ),
        .target(
            name: "TWSSnippet",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "com.inova.twssnippet",
            deploymentTargets: .iOS(deploymentTarget()),
            sources: ["TWSSnippet/Sources/**"],
            dependencies: [
                .target(name: "TWSCommon"),
                .target(name: "TWSModels"),
                .target(name: "TWSLogger")
            ],
            settings: .settings(
                configurations: internalConfigurations()
            )
        ),
        .target(
            name: "TWSSettings",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "com.inova.twssettings",
            deploymentTargets: .iOS(deploymentTarget()),
            sources: ["TWSSettings/Sources/**"],
            dependencies: [
                .target(name: "TWSCommon"),
                .target(name: "TWSModels"),
                .target(name: "TWSLogger")
            ],
            settings: .settings(
                configurations: internalConfigurations()
            )
        ),
        .target(
            name: "TWSModels",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.inova.twsmodels",
            deploymentTargets: .iOS(deploymentTarget()),
            sources: ["TWSModels/Sources/**"],
            dependencies: [
            ],
            settings: .settings(
                configurations: distributionConfigurations()
            )
        ),
        .target(
            name: "TWSModelsTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.inova.twsModelsTests",
            deploymentTargets: .iOS(deploymentTarget()),
            infoPlist: .default,
            sources: ["TWSModelsTests/Sources/**"],
            dependencies: [
                .target(name: "TWSModels")
            ],
            settings: .settings(
                configurations: testConfigurations()
            )
        ),
        .target(
            name: "TWSAPI",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "com.inova.twsapi",
            deploymentTargets: .iOS(deploymentTarget()),
            sources: ["TWSAPI/Sources/**"],
            dependencies: [
                .target(name: "TWSModels"),
                .target(name: "TWSLogger"),
                .target(name: "TWSFormatters"),
                .external(name: "SwiftJWT")
            ],
            settings: .settings(
                configurations: internalConfigurations()
            )
        ),
        .target(
            name: "TWSCommon",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "com.inova.twscommon",
            deploymentTargets: .iOS(deploymentTarget()),
            sources: ["TWSCommon/Sources/**"],
            dependencies: [
                .external(name: "ComposableArchitecture"),
                .external(name: "URLRouting"),
                .target(name: "TWSAPI"),
                .target(name: "TWSLogger")
            ],
            settings: .settings(
                configurations: internalConfigurations()
            )
        ),
        .target(
            name: "TWSLogger",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "com.inova.twslogger",
            deploymentTargets: .iOS(deploymentTarget()),
            infoPlist: .extendingDefault(with: loggerInfoPlist()),
            sources: ["TWSLogger/Sources/**"],
            dependencies: [
                .target(name: "TWSModels")
            ],
            settings: .settings(
                configurations: internalConfigurations()
            )
        ),
        .target(
            name: "TWSLoggerTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.inova.twsLoggerTests",
            deploymentTargets: .iOS(deploymentTarget()),
            infoPlist: .default,
            sources: ["TWSLoggerTests/Sources/**"],
            dependencies: [
                .target(name: "TWSLogger")
            ],
            settings: .settings(
                configurations: testConfigurations()
            )
        ),
        .target(
            name: "TWSUniversalLinks",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "com.inova.twsuniversallinks",
            deploymentTargets: .iOS(deploymentTarget()),
            sources: ["TWSUniversalLinks/Sources/**"],
            dependencies: [
                .target(name: "TWSModels"),
                .target(name: "TWSCommon"),
                .target(name: "TWSLogger")
            ],
            settings: .settings(
                configurations: internalConfigurations()
            )
        ),
        .target(
            name: "TWSUniversalLinksTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.inova.twsuniversallinksTests",
            deploymentTargets: .iOS(deploymentTarget()),
            infoPlist: .default,
            sources: ["TWSUniversalLinksTests/Sources/**"],
            dependencies: [
                .target(name: "TWSUniversalLinks")
            ],
            settings: .settings(
                configurations: testConfigurations()
            )
        ),
    ],
    schemes: [
        .scheme(
            name: "Playground",
            buildAction: .buildAction(targets: ["Playground"]),
            testAction: .targets(["TWSSnippetsTests", "TWSLoggerTests", "TWSUniversalLinksTests", "TWSModelsTests"], configuration: .configuration("Testing")),
            runAction: .runAction(),
            archiveAction: .archiveAction(configuration: "Playground"),
            profileAction: .profileAction(),
            analyzeAction: .analyzeAction(configuration: "Playground")
        ),
        .scheme(
            name: "Template",
            buildAction: .buildAction(targets: ["Template"]),
            testAction: .targets([]),
            runAction: .runAction(),
            archiveAction: .archiveAction(configuration: "Template"),
            profileAction: .profileAction(),
            analyzeAction: .analyzeAction(configuration: "Template")
        )
    ]
)

func deploymentTarget() -> String {
    "17.0"
}

func infoPlist() -> [String: Plist.Value] {
    [
        "UILaunchScreen": [:],
        "CFBundleDisplayName": "The Web Snippet",
        "CFBundleShortVersionString": "$(MARKETING_VERSION)",
        "CFBundleVersion": "${CURRENT_PROJECT_VERSION}",
        "NSLocationWhenInUseUsageDescription": "This app requires access to your location to enhance your experience by providing location-based features while you are using the app.",
        "NSCameraUsageDescription": "This app requires access to your camera to enhance your experience by providing camera-based features while you are using the app.",
        "NSMicrophoneUsageDescription": "This app requires access to your microphone to enhance your experience by providing microphone-based features while you are using the app.",
        "UIFileSharingEnabled": true,
        "LSSupportsOpeningDocumentsInPlace": true,
        "NSLocalNetworkUsageDescription": "Atlantis would use Bonjour Service to discover Proxyman app from your local network.",
        "NSBonjourServices": ["_Proxyman._tcp"]
    ]
}

func infoPlistTemplate() -> [String: Plist.Value] {
    var dict = infoPlist()
    dict.merge(
        [
            "TWSOrganizationID": "inova.tws",
            "TWSProjectId": "4166c981-56ae-4007-bc93-28875e6a2ca5"
        ],
        uniquingKeysWith: { _, _ in
            fatalError("Duplicate keys in info.plist template")
        }
    )

    return dict
}

func loggerInfoPlist() -> [String: Plist.Value] {
    [
        "OSLogPreferences": [
            "$(PRODUCT_BUNDLE_IDENTIFIER)": [
                "TWS": [
                    "Level": [
                        "Enable": "Debug",
                        "Persist": "Debug"
                    ]
                ],
                "TWSSnippets": [
                    "Level": [
                        "Enable": "Debug",
                        "Persist": "Debug"
                    ]
                ],
                "TWSCore": [
                    "Level": [
                        "Enable": "Debug",
                        "Persist": "Debug"
                    ]
                ],
                "TWSSnippet": [
                    "Level": [
                        "Enable": "Debug",
                        "Persist": "Debug"
                    ]
                ],
                "TWSCommon": [
                    "Level": [
                        "Enable": "Debug",
                        "Persist": "Debug"
                    ]
                ],
                "TWSSettings": [
                    "Level": [
                        "Enable": "Debug",
                        "Persist": "Debug"
                    ]
                ],
                "TWSApi": [
                    "Level": [
                        "Enable": "Debug",
                        "Persist": "Debug"
                    ]
                ],
                "TWSUniversalLinks": [
                    "Level": [
                        "Enable": "Debug",
                        "Persist": "Debug"
                    ]
                ]
            ]
        ],
        "Enable-Private-Data": true
    ]
}

func targetScripts() -> [TargetScript] {
    [
        .pre(
            script: #"""
            if $HOME/.local/bin/mise x -- which swiftlint > /dev/null; then
                $HOME/.local/bin/mise x -- swiftlint;
            else
                echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint";
            fi
            """#,
            name: "SwiftLint",
            basedOnDependencyAnalysis: false
        ),
        .post(
            script: #"""
            "${SRCROOT}/Tuist/.build/checkouts/firebase-ios-sdk/Crashlytics/run"
            """#,
            name: "Firebase Crashlystics",
            inputPaths: [
                "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}",
                "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${PRODUCT_NAME}",
                "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Info.plist",
                "$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/GoogleService-Info.plist",
                "$(TARGET_BUILD_DIR)/$(EXECUTABLE_PATH)"
            ],
            basedOnDependencyAnalysis: false
        )
    ]
}

func targetScriptsTemplate() -> [TargetScript] {
    [
        .pre(
            script: #"""
            if $HOME/.local/bin/mise x -- which swiftlint > /dev/null; then
                $HOME/.local/bin/mise x -- swiftlint;
            else
                echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint";
            fi
            """#,
            name: "SwiftLint",
            basedOnDependencyAnalysis: false
        )
    ]
}

func testConfigurations() -> [Configuration] {
    [
        .debug(
            name: "Debug",
            settings: ["SWIFT_VERSION": "6.0"],
            xcconfig: .relativeToRoot("config/TWSDemo_tests.xcconfig")
        ),
        .debug(
            name: "Testing",
            settings: ["SWIFT_VERSION": "6.0"],
            xcconfig: .relativeToRoot("config/TWSDemo_tests.xcconfig")
        ),
        .release(
            name: "Staging",
            settings: ["SWIFT_VERSION": "6.0"],
            xcconfig: .relativeToRoot("config/TWSDemo_tests.xcconfig")
        ),
        .release(
            name: "Release",
            settings: ["SWIFT_VERSION": "6.0"],
            xcconfig: .relativeToRoot("config/TWSDemo_tests.xcconfig")
        )
    ]
}

func distributionConfigurations() -> [Configuration] {
    [
        .debug(name: "Debug", settings: ["SWIFT_VERSION": "6.0"], xcconfig: .relativeToRoot("config/TWSDist.xcconfig")),
        .debug(name: "Testing", settings: ["SWIFT_VERSION": "6.0"], xcconfig: .relativeToRoot("config/TWSDistTests.xcconfig")),
        .release(name: "Staging", settings: ["SWIFT_VERSION": "6.0"], xcconfig: .relativeToRoot("config/TWSDist.xcconfig")),
        .release(name: "Release", settings: ["SWIFT_VERSION": "6.0"], xcconfig: .relativeToRoot("config/TWSDist.xcconfig"))
    ]
}

func internalConfigurations() -> [Configuration] {
    [
        .debug(name: "Debug", settings: ["SWIFT_VERSION": "6.0"]),
        .debug(name: "Testing", settings: ["SWIFT_VERSION": "6.0", "OTHER_SWIFT_FLAGS": "-DTESTING"]),
        .release(name: "Staging", settings: ["SWIFT_VERSION": "6.0"]),
        .release(name: "Release", settings: ["SWIFT_VERSION": "6.0"])
    ]
}
