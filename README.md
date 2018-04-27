# Mobile Messaging SDK for iOS

[![Version](https://img.shields.io/cocoapods/v/MobileMessaging.svg?style=flat)](http://cocoapods.org/pods/MobileMessaging)
[![License](https://img.shields.io/cocoapods/l/MobileMessaging.svg?style=flat)](http://cocoapods.org/pods/MobileMessaging)
[![Platform](https://img.shields.io/cocoapods/p/MobileMessaging.svg?style=flat)](http://cocoapods.org/pods/MobileMessaging)

Mobile Messaging SDK is designed and developed to easily enable push notification channel in your mobile application. In almost no time of implementation you get push notification in your application and access to the features of [Infobip IP Messaging Platform](https://portal.infobip.com/push/). This document describes library integration steps. Additional information on advanced topics can be found in our [wiki page](https://github.com/infobip/mobile-messaging-sdk-ios/wiki).

## Requirements
- Xcode 9.3
- iOS 9.0+

<!-- ## Usage -->
## Quick start guide
This guide is designed to get you up and running with Mobile Messaging SDK integrated into your iOS application.

1. Prepare your App ID, provisioning profiles and APNs certificate ([APNs Certificate Guide](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/APNs-Certificate-guide)).
2. Prepare your Infobip account (https://portal.infobip.com/push/) to get your Application Code:
	1. [Create new application](https://dev.infobip.com/v1/docs/push-introduction-create-app) on Infobip Push portal.
	2. Navigate to your Application where you will get the Application Code.
	3. Mark the "Available on iOS" checkbox.
	4. Mark the "Sandbox" checkbox if you are using sandbox environment for the application.
	5. Click on "UPLOAD" under "APNS Certificates" and locate the .p12 certificate you exported from your Keychain earlier.

	<center><img src="https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Images/CUPCertificate.png?raw=true" alt="CUP Settings"/></center>
3. Configure your project to support Push Notifications:
	1. Click on "Capabilities", then turn on Push Notifications. Entitlements file should be automatically created by XCode with set `aps-environment` value.
	2. Turn on Background Modes and check the Remote notifications checkbox.
4. Installation

	#### CocoaPods
	To integrate MobileMessaging into your Xcode project using [CocoaPods](https://guides.cocoapods.org/using/getting-started.html#getting-started), specify it in your `Podfile`:

	```ruby
	source 'https://github.com/CocoaPods/Specs.git'
	platform :ios, '8.0'
	use_frameworks!
	pod 'MobileMessaging'
	```

	> ### Notice 
	> CocoaLumberjack logging used by default, in order to use other logging or switch it off follow [this guide](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/How-to-install-the-SDK-without-CocoaLumberjack%3F).

	#### Carthage
	If you use [Carthage](https://github.com/Carthage/Carthage/#readme) to manage your dependencies, just add MobileMessaging to your `Cartfile`:

	```
	github "infobip/mobile-messaging-sdk-ios"
	```

	If you use Carthage to build your dependencies, make sure you have added `MobileMessaging.framework` to the "Linked Frameworks and Libraries" section of your target, and have included them in your Carthage framework copying build phase (as described in [Carthage documentation](https://github.com/Carthage/Carthage/blob/master/README.md)).
	If your application target does not contain Swift code at all, you should also set the `EMBEDDED_CONTENT_CONTAINS_SWIFT` build setting to “Yes”.

5. Perform [code modification to the app delegate](#app-delegate-changes) in order to receive push notifications.

6. At this step you are all set for receiving regular push notifications. There are several advanced features that you may find really useful for your product, though:
	- [Rich Notifications and better delivery reporting(available with iOS 10)](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Using-Notification-Service-Extension-for-Rich-Notifications-and-better-delivery-reporting-on-iOS-10)
	- [Geofencing Service](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Geofencing-service)

### App Delegate Changes

The simplest approach to integrate Mobile Messaging SDK with an existing app is by adding the SDK calls into your app delegate:

1. Import the library:

	```swift
	// Swift
	import MobileMessaging
	```

	```objective-c
	// Objective-C
	@import MobileMessaging;
	```
2. Start MobileMessaging service using your Infobip Application Code, obtained in step 2, and preferable notification type as parameters:

	```swift
	// Swift
	func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        MobileMessaging.withApplicationCode(<#your application code#>, notificationType: <#for example UserNotificationType(options: [.alert, .sound])#>)?.start()
		...
	}	
	```

	```objective-c
	// Objective-C
	- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
        UserNotificationType *userNotificationType = [[UserNotificationType alloc] initWithOptions:<#for example @[UserNotificationType.alert, UserNotificationType.sound]#>;
        [[MobileMessaging withApplicationCode: <#your application code#> notificationType: userNotificationType] start:nil];
		...
	}
	```
4. Override method `application:didRegisterForRemoteNotificationsWithDeviceToken:` in order to inform Infobip about the new device registered:

	```swift
	// Swift
	func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
		MobileMessaging.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken)
	}
	```

	```objective-c
	// Objective-C
	- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
		[MobileMessaging didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
	}
	```
5. Override method `application:didReceiveRemoteNotification:fetchCompletionHandler:` in order to send notification delivery reports to Infobip:

	```swift
	// Swift
	func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
		MobileMessaging.didReceiveRemoteNotification(userInfo, fetchCompletionHandler: completionHandler)
	}
	```

	```objective-c
	// Objective-C
	- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
		[MobileMessaging didReceiveRemoteNotification:userInfo fetchCompletionHandler:completionHandler];
	}
	```
6. Override method `application:didReceiveLocalNotification`(for Objective-C) or `application:didReceive:`(for Swift 3) in order the MobileMessaging SDK to be able to handle incoming local notifications internally:

	```swift
	// Swift
	func application(_ application: UIApplication, didReceive notification: UILocalNotification) {
		MobileMessaging.didReceiveLocalNotification(notification)
	}
	```

	```objective-c
	// Objective-C
    -(void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
        [MobileMessaging didReceiveLocalNotification:notification];
    }
	```

## Mobile Messaging APIs

### Events

Library informs you about following events using NSNotificationCenter:

* __Message received__ - is triggered after a message has been received.
* __Device token received__ - is triggered after an APNS registration token has been received from APNS.
* __Registration updated__ - is triggered after an APNS registration token has been successfully stored on the server.
* __API error__ - is triggered on every error returned by API.
* __Delivery reports sent__ - is triggered after a message delivery has been reported.
* __Message will be sent__ - is triggered when a mobile originated message is about to be sent to the server.
* __Message did send__ - is triggered after a mobile originated message has been sent to the server.
* etc.

More information on library events available on our [wiki page](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Library-events).

### Linking with MSISDN

It is recommended that you link the GSM number (in [MSISDN](https://en.wikipedia.org/wiki/MSISDN) format).
It will give an additional opportunity to target your application users and orchestrate your campaigns with [OMNI Messaging service](https://dev.infobip.com/docs/omni-introduction) including SMS fallback feature.

```swift
// Swift
MobileMessaging.currentUser?.save(msisdn: <#for example "79091234567"#>, completion:
	{ error in
		<#handle the error if needed#>
	}
)
```

```objective-c
// Objective-C
[[MobileMessaging currentUser] saveWithMsisdn: <#for example @"79091234567"#>
								   completion: ^(NSError * _Nullable error)
{
	<#handle the error if needed#>
}];
```
