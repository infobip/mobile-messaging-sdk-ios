# Mobile Messaging SDK for iOS

[![Version](https://img.shields.io/cocoapods/v/MobileMessaging.svg?style=flat)](http://cocoapods.org/pods/MobileMessaging)
[![License](https://img.shields.io/cocoapods/l/MobileMessaging.svg?style=flat)](http://cocoapods.org/pods/MobileMessaging)
[![Platform](https://img.shields.io/cocoapods/p/MobileMessaging.svg?style=flat)](http://cocoapods.org/pods/MobileMessaging)

Mobile Messaging SDK is designed and developed to easily enable push notification channel in your mobile application. In almost no time of implementation you get push notification in your application and access to the features of <a href="https://www.infobip.com/en/products/mobile-app-messaging" target="_blank">Infobip Mobile Apps Messaging</a>. The document describes library integration steps. Additional information can be found in our <a href="https://github.com/infobip/mobile-messaging-sdk-ios/wiki" target="_blank">Wiki</a>.

## Requirements
- Xcode 10
- Swift 4.2
- iOS 9.0+

<!-- ## Usage -->
## Quick start guide
This guide is designed to get you up and running with Mobile Messaging SDK integrated into your iOS application.

1. Make sure to [setup application at Infobip portal](https://dev.infobip.com/push-messaging), if you haven't already.
2. Configure your project to support Push Notifications:
    1. Click on "Capabilities", then turn on Push Notifications. Entitlements file should be automatically created by Xcode with set `aps-environment` value.
    <img src="https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Images/push_capabilities.png?raw=true" alt="Enable Push Notifications capability"/>
    
    2. Turn on Background Modes and check the Remote notifications checkbox.
    <img src="https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Images/background_modes.png?raw=true" alt="Enable Remote Notifications in Background Modes settings"/>
3. Using [CocoaPods](https://guides.cocoapods.org/using/getting-started.html#getting-started), specify it in your `Podfile`:

    ```ruby
    source 'https://github.com/CocoaPods/Specs.git'
    platform :ios, '9.0'
    use_frameworks!
    pod 'MobileMessaging'
    ```

    > #### Notice 
    > CocoaLumberjack logging used by default, in order to use other logging or switch it off follow [this guide](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/How-to-install-the-SDK-without-CocoaLumberjack%3F).

    If you use Carthage, see [Integration via Carthage](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Integration-via-Carthage) guide.

4. Import the library into your AppDelegate file:

    ```swift
    // Swift
    import MobileMessaging
    ```
    <details><summary>expand to see Objective-C code</summary>
    <p>

    ```objective-c
    @import MobileMessaging;
    ```

    </p>
    </details>

5. Start MobileMessaging service using your Infobip Application Code, obtained in step 1, and preferable notification type as parameters:

    ```swift
    // Swift
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        MobileMessaging.withApplicationCode(<#your application code#>, notificationType: <#for example UserNotificationType(options: [.alert, .sound])#>)?.start()
        ...
    }   
    ```

    <details><summary>expand to see Objective-C code</summary>
    <p>

    ```objective-c
    - (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
        UserNotificationType *userNotificationType = [[UserNotificationType alloc] initWithOptions:<#for example @[UserNotificationType.alert, UserNotificationType.sound]#>;
        [[MobileMessaging withApplicationCode: <#your application code#> notificationType: userNotificationType] start:nil];
        ...
    }
    ```

    </p>
    </details>

    Please note that it is not very secure to keep your API key (Application Code is an API key in fact) hardcoded so if the security is a crucial aspect, consider obfuscating the Application Code string (we can recommend [UAObfuscatedString](https://github.com/UrbanApps/UAObfuscatedString) for string obfuscation).

6. Override method `application:didRegisterForRemoteNotificationsWithDeviceToken:` in order to inform Infobip about the new device registered:

    ```swift
    // Swift
    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        MobileMessaging.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken)
    }
    ```

    <details><summary>expand to see Objective-C code</summary>
    <p>

    ```objective-c
    - (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
        [MobileMessaging didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
    }
    ```

    </p>
    </details>

7. Override method `application:didReceiveRemoteNotification:fetchCompletionHandler:` in order to send notification delivery reports to Infobip:

    ```swift
    // Swift
    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        MobileMessaging.didReceiveRemoteNotification(userInfo, fetchCompletionHandler: completionHandler)
    }
    ```

    <details><summary>expand to see Objective-C code</summary>
    <p>

    ```objective-c
    - (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
        [MobileMessaging didReceiveRemoteNotification:userInfo fetchCompletionHandler:completionHandler];
    }
    ```

    </p>
    </details>

8. **Skip this step if your apps minimum deployment target is iOS 10 or later.** Override method `application:didReceiveLocalNotification`(for Objective-C) or `application:didReceive:`(for Swift) in order the MobileMessaging SDK to be able to handle incoming local notifications internally:

    ```swift
    // Swift
    func application(_ application: UIApplication, didReceive notification: UILocalNotification) {
        MobileMessaging.didReceiveLocalNotification(notification)
    }
    ```

    <details><summary>expand to see Objective-C code</summary>
    <p>

    ```objective-c
    -(void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
        [MobileMessaging didReceiveLocalNotification:notification];
    }
    ```

    </p>
    </details>
<br>
In case of a clean project, your AppDeleage.swift code should look like following:
<img src="https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Images/app_delegate.png?raw=true" alt="AppDelegate source code example"/>


<br>
<p align="center"><b>NEXT STEPS: <a href="https://github.com/infobip/mobile-messaging-sdk-android/wiki/User-profile">User profile</a></b></p>
<br>
<br>

| If you have any questions or suggestions, feel free to send an email to support@infobip.com or create an <a href="https://github.com/infobip/mobile-messaging-sdk-ios/issues" target="_blank">issue</a>. |
|---|