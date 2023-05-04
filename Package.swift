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
            name: "InfobipMobileMessaging",
            targets: ["MobileMessaging", "MobileMessagingObjC"]),
    ],
    targets: [
        .target(name: "MobileMessaging", dependencies: ["MobileMessagingObjC"], path: "Classes/MobileMessaging"),
        .target(name: "MobileMessagingObjC", path: "Classes/MobileMessagingObjC", exclude: ["Core/Plugins/MobileMessagingPluginApplicationDelegate.m", "Headers/MobileMessagingPluginApplicationDelegate.h"], publicHeadersPath: "Headers"),
    ]
)
