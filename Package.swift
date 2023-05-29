// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "InfobipMobileMessaging",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "MobileMessaging",
            targets: ["MobileMessaging", "MobileMessagingObjC"]),
        .library(name: "InAppChat", targets: ["InAppChat"]),
        .library(name: "WebRTCUI", targets: ["WebRTCUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/infobip/infobip-rtc-ios.git", "2.0.8"..<"2.0.21")
    ],
    targets: [
        .target(name: "MobileMessaging", dependencies: ["MobileMessagingObjC"], path: "Classes/MobileMessaging", resources: [
            .process("Resources/InteractiveNotifications/PredefinedNotificationCategories.plist")]),
        .target(name: "MobileMessagingObjC", path: "Classes/MobileMessagingObjC", exclude: ["Core/Plugins/MobileMessagingPluginApplicationDelegate.m", "Headers/MobileMessagingPluginApplicationDelegate.h"], publicHeadersPath: "Headers"),
        .target(
            name: "InAppChat",
            dependencies: [
                "MobileMessaging",
            ],
            path: "Classes/Chat",
            resources: [.copy("Resources/ChatConnector.html")],
            cSettings: [.define("WEBRTCUI_ENABLED")]
        ),
        .target(
            name: "WebRTCUI",
            dependencies: [
                "MobileMessaging",
                .product(name: "InfobipRTC", package: "infobip-rtc-ios"),
                .product(name: "WebRTC", package: "infobip-rtc-ios")
            ],
            path: "Classes/WebRTCUI",
            cSettings: [.define("WEBRTCUI_ENABLED")],
            swiftSettings: [.define("WEBRTCUI_ENABLED")]
        )
    ]
)
