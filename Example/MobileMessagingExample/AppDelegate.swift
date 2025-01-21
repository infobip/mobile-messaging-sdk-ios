//
//  AppDelegate.swift
//  MobileMessaging
//
//  Created by Andrey K. on 03/29/2016.

import UIKit
import MobileMessaging
#if USING_SPM
import MobileMessagingInbox
import InAppChat
import WebRTCUI
#endif
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    let messagesManager = MessagesManager.sharedInstance
    
    func applicationDidFinishLaunching(_ application: UIApplication) {
        if !ProcessInfo.processInfo.arguments.contains("-IsStartedToRunTests") {
            setupLogging()
            MobileMessaging
                .withApplicationCode(
                    "<# your application code #>",
                    notificationType: MMUserNotificationType(options: [.alert, .sound]))?
                .withInteractiveNotificationCategories(customCategories)
                .start()
        }
        UIToolbar.setupAppearance()
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        MobileMessaging.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        if MM_MTMessage.isCorrectPayload(userInfo) {
            MobileMessaging.didReceiveRemoteNotification(userInfo, fetchCompletionHandler: completionHandler)
        } else {
            // Other push vendors might have their code here and handle a remote notification as well.
            // completionHandler needs to be called only once.
            completionHandler(.noData)
        }
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return LinksHandler.openDeeplink(url: url, withMessage: nil)
    }
}
