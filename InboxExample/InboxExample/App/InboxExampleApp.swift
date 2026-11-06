//
//  InboxExample/InboxExample/App/InboxExampleApp.swift
//  InboxExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import SwiftUI
import MobileMessaging

@main
struct InboxExampleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var app = AppModel.shared
    @StateObject private var inbox = InboxModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(app)
                .environmentObject(inbox)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // The Application Code is entered in Settings, so the example runs without editing code.
        // A real app starts the SDK here directly:
        // MobileMessaging.withApplicationCode(<# your Application Code #>, notificationType: [.alert, .sound])?.start()
        MobileMessaging.logger = MMDefaultLogger()
        AppModel.shared.startSDK()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        MobileMessaging.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        MobileMessaging.didReceiveRemoteNotification(userInfo, fetchCompletionHandler: completionHandler)
    }
}

struct ContentView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var inbox: InboxModel
    @State private var tab = AppModel.shared.inboxUser == nil ? 1 : 0

    var body: some View {
        TabView(selection: $tab) {
            NavigationView { InboxView() }
                .navigationViewStyle(.stack)
                .tabItem { Label("Inbox", systemImage: "tray") }
                .badge(inbox.countUnread)
                .tag(0)
            NavigationView { SettingsView() }
                .navigationViewStyle(.stack)
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(1)
        }
        // Registration and personalization change who the inbox belongs to.
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name(MMNotificationRegistrationUpdated))) { _ in app.refreshStatus() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name(MMNotificationPersonalized))) { _ in app.refreshStatus() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name(MMNotificationDepersonalized))) { _ in app.refreshStatus() }
    }
}
