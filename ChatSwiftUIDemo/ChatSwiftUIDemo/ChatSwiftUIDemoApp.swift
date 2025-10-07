// 
//  ChatSwiftUIDemo/ChatSwiftUIDemo/ChatSwiftUIDemoApp.swift
//  ChatSwiftUIDemo
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
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
