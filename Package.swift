// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "InfobipMobileMessaging",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "InfobipMobileMessaging",
            targets: ["MobileMessagingWrapper"]),
    ],
    targets: [
        .target(name: "MobileMessagingWrapper", dependencies: ["MobileMessaging"]),
        .binaryTarget(
          name: "MobileMessaging",
          url: "https://github.com/infobip/mobile-messaging-sdk-ios/releases/download/10.9.0/MobileMessaging.xcframework.zip",
          checksum: "0184cc0617a92d4258529609247c432d507c36b650b367dd2d883e74c029010d"),
    ]
)
