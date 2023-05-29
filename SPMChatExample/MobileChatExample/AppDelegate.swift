//
//  AppDelegate.swift
//  MobileChatExample
//
//  Created by Andrey Kadochnikov on 10/11/2017.
//  Copyright © 2017 Infobip d.o.o. All rights reserved.
//
//

import UIKit
import MobileMessaging
import InfobipRTC
import WebRTCUI
import InAppChat

let mmApplicationCode = "<# your mobile application code #>"
let webrtcApplicationId = "<# your webrtc app id #>"

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        MobileMessaging.withApplicationCode(
            mmApplicationCode, notificationType: .alert)?.withInAppChat().withCalls(webrtcApplicationId).start()
        MobileMessaging.logger?.logLevel = .All
        MobileMessaging.logger?.logOutput = .Console
        MobileMessaging.webRTCService?.callAppIcon = UIImage(named: "alphaLogo")
        MobileMessaging.webRTCService?.settings.inboundCallSoundFileName = "MMInboundCall.wav" // filename for audio file in your project
        //MobileMessaging.webRTCService?.delegate = self // Set a delegate for webrtc if you want to handle calls yourself
        //customiseCallsUI() // Change the colors, icons and sounds of the call UI
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        MobileMessaging.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        MobileMessaging.didReceiveRemoteNotification(userInfo, fetchCompletionHandler: completionHandler)
    }
}

//Uncomment if you wish to customise the provided calls UI
/*extension AppDelegate {
    func customiseCallsUI() {
        // example on seting up UI colors from a dictionary
        let colorConfig = [
            "rtc_ui_pulse_stroke": "#ffaaaa",
            "rtc_ui_error": "#ff0033",
            "rtc_ui_primary": "#55ff66",
            "rtc_ui_color_foreground": "#ccffff",
            "rtc_ui_color_text_secondary": "#ffccdd",
            "rtc_ui_color_background": "#123456",
            "rtc_ui_color_overlay_background": "#234567",
            "rtc_ui_color_alert_background": "#987654"]
        MobileMessaging.webRTCService?.settings.configureWith(rawConfig: colorConfig)
        // example on overwritting a color directly
        MobileMessaging.webRTCService?.settings.backgroundColor = .darkGray
        // example on overwritting a sound (wav or mp3 must be in your main bundle)
        MobileMessaging.webRTCService?.settings.soundEndCall = NSDataAsset(name: "phone-ringing-sound")
        // example on overwritting an icon (file must be in your main bundle)
        MobileMessaging.webRTCService?.settings.iconAvatar = UIImage(named: "icon-user-border")
    }
}*/

// Uncomment if you wish to define a delegate for calls of your own.
/*extension AppDelegate: MMWebRTCDelegate {
    func inboundCallEstablished(_ call: ApplicationCall, event: CallEstablishedEvent) {
        if let rootVC = window?.rootViewController?.children.first as? ViewController,
        let callController = MobileMessaging.webRTCService?.getInboundCallController(incoming: call, establishedEvent: event) {
            /* Note: this is just an example. You are free to display and handle the call as you please:
             1 - You can leave MobileMessaging.webRTCService.delegate empty. WebRTCUI will display the built-in UI for you.
             2 - You can define a MobileMessaging.webRTCService.delegate, and handle the call by:
                a) Displaying/reusing our WebRTUI as you please
                b) Using any custom UI of your own to handle the call
             */
            rootVC.showCallUI(in: callController)
        }
    }
}*/
