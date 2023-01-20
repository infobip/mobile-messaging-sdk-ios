//
//  AppDelegate.swift
//  InboxExample
//
//  Created by Andrey Kadochnikov on 25.05.2022.
//

import UIKit
import MobileMessaging

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        MobileMessaging.withApplicationCode(<# use your own Application Code #>, notificationType: [MMUserNotificationType.alert, MMUserNotificationType.sound])?.start()
        MobileMessaging.logger = MMDefaultLogger()
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        MobileMessaging.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        MobileMessaging.didReceiveRemoteNotification(userInfo, fetchCompletionHandler: completionHandler)
    }
}
