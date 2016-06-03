# Mobile Messaging SDK for iOS

[![Version](https://img.shields.io/cocoapods/v/MobileMessaging.svg?style=flat)](http://cocoapods.org/pods/MobileMessaging)
[![License](https://img.shields.io/cocoapods/l/MobileMessaging.svg?style=flat)](http://cocoapods.org/pods/MobileMessaging)
[![Platform](https://img.shields.io/cocoapods/p/MobileMessaging.svg?style=flat)](http://cocoapods.org/pods/MobileMessaging)

Mobile Messaging SDK is designed and developed to easily enable push notification channel in your mobile application. In almost no time of implementation you get push notification in your application and access to the features of [Infobip IP Messaging Platform](https://portal.infobip.com/push/). 
The document describes library integration steps.

## Requirements
- Xcode 7.3+
- iOS 8.0+

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
	1. Click on "Capabilities", then turn on Push Notifications.
	2. Turn on Background Modes and check the Remote notifications checkbox.
4. To integrate MobileMessaging into your Xcode project using [CocoaPods](https://guides.cocoapods.org/using/getting-started.html#getting-started), specify it in your Podfile:

	```ruby
	source 'https://github.com/CocoaPods/Specs.git'
	platform :ios, '8.0'
	use_frameworks!
	pod 'MobileMessaging'
	```
5. Perform code modification to the app delegate in order to receive push notifications. There are two ways to do this: [App Delegate Inheritance](#app-delegate-inheritance) or [App Delegate Composition](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Integration-via-app-delegate-composition)


### App Delegate Inheritance
The simplest approach to integrate Mobile Messaging with an existing app is by inheriting your app delegate from `MobileMessagingAppDelegate`. If you prefer a more advanced way: [App Delegate Composition](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Integration-via-app-delegate-composition).

1. Import the library, into your `AppDelegate` declaration file:

	```swift
	// Swift
	import MobileMessaging
	```

	```objective-c
	// Objective-C
	@import MobileMessaging;
	```
2. Inherit your `AppDelegate` from `MobileMessagingAppDelegate` or `MobileMessagingAppDelegateObjc` depending on your project's language:

	```swift
	// Swift
	class AppDelegate: MobileMessagingAppDelegate {
		...
	}
	```

	```objective-c
	// Objective-C
	@interface AppDelegate : MobileMessagingAppDelegateObjc
	```
3. Override `applicationCode` and `userNotificationType` variables in your `AppDelegate` providing appropriate values:

	```swift
	// Swift
	override var applicationCode: String {
		return "your_application_code"
	}
	override var userNotificationType: UIUserNotificationType {
		return [.Alert, .Sound]
	}
	```

	```objective-c
	// Objective-C
	-(NSString *)applicationCode {
		return @"your_application_code";
	}
	-(UIUserNotificationType)userNotificationType {
		return UIUserNotificationTypeAlert | UIUserNotificationTypeSound;
	}
	```
4. If you have any of following application callbacks implemented in your AppDelegate:

	* `application(:didFinishLaunchingWithOptions:)`
	* `application(:didRegisterForRemoteNotificationsWithDeviceToken:)`
	* `application(:didReceiveRemoteNotification:fetchCompletionHandler:)`

	, rename it to corresponding:

	* `mm_application(:didFinishLaunchingWithOptions:)`
	* `mm_application(:didRegisterForRemoteNotificationsWithDeviceToken:)`
	* `mm_application(:didReceiveRemoteNotification:fetchCompletionHandler:)`


## Mobile Messaging APIs

### Events

Library informs you about following events using NSNotificationCenter:

* __Message received__ - is triggered when message is received.
* __Device token updated__ - is triggered when device token is updated.
* __Registration updated__ - is triggered when APNS registration token successfully stored on the registration server.
* __API error__ - is triggered on every error returned by API.
* __Delivery reports sent__ - is triggered when message delivery is reported.


### Linking MSISDN

It is recommended that you link the Telephone number (in [MSISDN](https://en.wikipedia.org/wiki/MSISDN) format).
It will give an additional opportunity to target your application users and orchestrate your campaigns with [OMNI Messaging service](https://dev.infobip.com/docs/omni-introduction) including SMS fallback feature.

```swift
// Swift
MobileMessaging.currentInstallation?.saveMSISDN("385911234567", completion: { error in
	// if an error occurs, handle it
})
```

```objective-c
// Objective-C
[[MobileMessaging currentInstallation] saveMSISDN:@"385911234567" completion:^(NSError * _Nullable error) {
	// if an error occurs, handle it
}];
```