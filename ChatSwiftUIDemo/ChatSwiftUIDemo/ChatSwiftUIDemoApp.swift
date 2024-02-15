//
//  ChatSwiftUIDemoApp.swift
//  ChatSwiftUIDemo
//
//  Created by Maksym Svitlovskyi on 14/02/2024.
//  Copyright © 2023 Infobip Ltd. All rights reserved.
//

import SwiftUI
import MobileMessaging
import InAppChat
import WebRTCUI
import InfobipRTC

let mmApplicationCode = ""
let webrtcConfigurationId = ""

class AppDelegate: NSObject, UIApplicationDelegate, ObservableObject {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        MobileMessaging.logger?.logLevel = .All
        MobileMessaging.logger?.logOutput = .Console
        MobileMessaging.withApplicationCode(
            mmApplicationCode, notificationType: [.alert, .sound]
        )?
            .withInAppChat()
            .withInAppChatCalls(configurationId: webrtcConfigurationId).start()
        return true
    }
    
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        MobileMessaging.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        MobileMessaging.didReceiveRemoteNotification(userInfo, fetchCompletionHandler: completionHandler)
    }
}


@main
struct ChatSwiftUIDemoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
