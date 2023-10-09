# Mobile Messaging SDK for iOS

[![Version](https://img.shields.io/cocoapods/v/MobileMessaging.svg?style=flat)](http://cocoapods.org/pods/MobileMessaging)
[![License](https://img.shields.io/cocoapods/l/MobileMessaging.svg?style=flat)](http://cocoapods.org/pods/MobileMessaging)
[![Platform](https://img.shields.io/cocoapods/p/MobileMessaging.svg?style=flat)](http://cocoapods.org/pods/MobileMessaging)

Mobile Messaging SDK is designed and developed to easily enable push notification channel in your mobile application. In almost no time of implementation you get push notification in your application and access to the features of <a href="https://www.infobip.com/en/products/mobile-app-messaging" target="_blank">Infobip Mobile Apps Messaging</a>. The document describes library integration steps. Additional information can be found in our <a href="https://github.com/infobip/mobile-messaging-sdk-ios/wiki" target="_blank">Wiki</a>.

## Requirements
- Xcode 15+
- Swift 4.2, Swift 5
- iOS 12.0+

## Quick start guide
This guide is designed to get you up and running with Mobile Messaging SDK integrated into your iOS application.

1. Make sure to <a href="https://www.infobip.com/docs/mobile-app-messaging/create-mobile-application-profile" target="_blank">setup application at Infobip portal</a>, if you haven't already.

2. Configure your project to support Push Notifications:
    1. Click on "Capabilities", then turn on Push Notifications. Entitlements file should be automatically created by Xcode with set `aps-environment` value.
    <img src="https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Images/push_capabilities.png?raw=true" alt="Enable Push Notifications capability"/>
    
    2. Turn on Background Modes and check the Remote notifications checkbox.
    <img src="https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Images/background_modes.png?raw=true" alt="Enable Remote Notifications in Background Modes settings"/>
    
3. Using <a href="https://guides.cocoapods.org/using/getting-started.html#getting-started" target="_blank">CocoaPods</a>, specify it in your `Podfile`:

    ```ruby
    source 'https://github.com/CocoaPods/Specs.git'
    platform :ios, '12.0'
    use_frameworks!
    pod 'MobileMessaging'
    ```

    > #### Notice 
    > CocoaLumberjack logging used by default, in order to use other logging or switch it off follow [this guide](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/How-to-install-the-SDK-without-CocoaLumberjack%3F).

    If you use Carthage, see <a href="https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Integration-via-Carthage" target="_blank">Integration via Carthage</a> guide.

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
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        MobileMessaging.withApplicationCode(<#your application code#>, notificationType: <#for example MMUserNotificationType(options: [.alert, .sound])#>)?.start()
        ...
    }   
    ```

    <details><summary>expand to see Objective-C code</summary>
    <p>

    ```objective-c
    - (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
        MMUserNotificationType *userNotificationType = [[MMUserNotificationType alloc] initWithOptions:<#for example @[MMUserNotificationType.alert, MMUserNotificationType.sound]#>;
        [[MobileMessaging withApplicationCode: <#your application code#> notificationType: userNotificationType] start:nil];
        ...
    }
    ```

    </p>
    </details>

    In case you already use other Push Notifications vendor's SDK, add `withoutRegisteringForRemoteNotifications()` to the start call:
    
    ```swift
    // Swift
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        MobileMessaging.withApplicationCode(<#your application code#>, notificationType: <#for example MMUserNotificationType(options: [.alert, .sound])#>)?.withoutRegisteringForRemoteNotifications()?.start()
        ...
    }   
    ```

    Please note that it is not very secure to keep your API key (Application Code is an API key in fact) hardcoded so if the security is a crucial aspect, consider obfuscating the Application Code string (we can recommend <a href="https://github.com/UrbanApps/UAObfuscatedString" target="_blank">UAObfuscatedString</a> for string obfuscation).

6. Add one line of code `MobileMessaging.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken)` to your AppDelegate method `application:didRegisterForRemoteNotificationsWithDeviceToken:` in order to inform Infobip about the new device registered:

    ```swift
    // Swift
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        MobileMessaging.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken)
        
        // other push vendors might have their code here and handle a Device Token as well
    }
    ```

    <details><summary>expand to see Objective-C code</summary>
    <p>

    ```objective-c
    - (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
        [MobileMessaging didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];

        // other push vendors might have their code here and handle a Device Token as well
    }
    ```

    </p>
    </details>

7. Add one line of code `MobileMessaging.didReceiveRemoteNotification(userInfo, fetchCompletionHandler: completionHandler)` to your AppDelegate method `application:didReceiveRemoteNotification:fetchCompletionHandler:` in order to send notification's delivery reports to Infobip:

    ```swift
    // Swift
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        MobileMessaging.didReceiveRemoteNotification(userInfo, fetchCompletionHandler: completionHandler)

        // other push vendors might have their code here and handle a remove notification as well
    }
    ```

    <details><summary>expand to see Objective-C code</summary>
    <p>

    ```objective-c
    - (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
        [MobileMessaging didReceiveRemoteNotification:userInfo fetchCompletionHandler:completionHandler];

        // other push vendors might have their code here and handle a remove notification as well
    }
    ```

    </p>
    </details>

8. [Integrate Notification Service Extension](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Notification-Service-Extension-for-Rich-Notifications-and-better-delivery-reporting-on-iOS-10) into your app in order to obtain:
    - more accurate processing of messages and delivery stats
    - support of rich notifications on the lock screen

<br>
In case of a clean project, your AppDelegate.swift code should look like following:
<img src="https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Images/app_delegate.png?raw=true" alt="AppDelegate source code example"/>

If all the steps implemented correctly, run your application on a real device, you should see the logs in Xcode console confirming that the MobileMessaging SDK has been initialized succesfully and the device has been registered on APNS to receive Push messages:
```
2023-01-28 18:24:16:003 [MobileMessaging] ℹ️ SDK successfully initialized!
...
2023-01-28 18:25:44:144 [MobileMessaging] ℹ️ [APNS reg manager] Application did register with device token <...>
```
If you don't see any logs, set up the default logger before starting the SDK: `MobileMessaging.logger = MMDefaultLogger()`. Please note that the logs are only collected while your project is in "debug" configuration.

**Please pay close attention to a Provisioning Profile that is used for your project build. It must match the APNs environment! If they don't, we'll invalidate the device push registration (more information here [I don't receive push notifications!](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/I-don't-receive-push-notifications)**

> #### Notice
> Push notifications (if they are not [in-app](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/In-app-notifications)) are not displayed automatically when the app is on the foreground. For further information check [FAQ - How to display messages when app is running in the foreground?](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/How-to-display-messages-when-app-is-running-in-the-foreground%3F).

<br>
<p align="center"><b>NEXT STEPS: <a href="https://github.com/infobip/mobile-messaging-sdk-ios/wiki/User-profile">User profile</a></b></p>
<br>
<br>

| If you have any questions or suggestions, feel free to send an email to support@infobip.com or create an <a href="https://github.com/infobip/mobile-messaging-sdk-ios/issues" target="_blank">issue</a>. |
|---|
