// 
//  Example/MobileMessagingExample/AppDelegate.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

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
            
            let jwtSupplier = JwtSupplierExampleImpl()
            jwtSupplier.setExternalUserId("jwtExtUserId1")
            
            let jwtSupplierNil = JwtSupplierExampleNilImpl()
            
            MobileMessaging
                .withApplicationCode(
                    "<# your application code #>",
                    notificationType: MMUserNotificationType(options: [.alert, .sound]))?
                .withInteractiveNotificationCategories(customCategories)
                .withFullFeaturedInApps()
                .withJwtSupplier(jwtSupplier)
                .start()
            
            MobileMessaging.jwtSupplier = jwtSupplierNil
            //MobileMessaging.setJwtSupplier(jwtSupplier)
        }
        UIToolbar.setupAppearance()
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        MobileMessaging.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        if MM_MTMessage.isCorrectPayload(userInfo) {
            let internalData = userInfo["internalData"] as? [String: Any] ?? [:]
            let isSilent = internalData["silent"] != nil
            let isNewInApp = internalData["inAppDetails"] != nil

            let isExpired = (internalData["validUntil"] as? NSNumber).map {
                Date().timeIntervalSince1970 > $0.doubleValue / 1000.0
            } ?? false
            
            if isSilent && !isNewInApp && !isExpired {
                if let message = MM_MTMessage.make(withPayload: userInfo) {
                    MobileMessaging.scheduleUserNotification(with: message) {
                        MobileMessaging.didReceiveRemoteNotification(userInfo, fetchCompletionHandler: completionHandler)
                    }
                }
            } else if !isExpired {
                MobileMessaging.didReceiveRemoteNotification(userInfo, fetchCompletionHandler: completionHandler)
            }
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
