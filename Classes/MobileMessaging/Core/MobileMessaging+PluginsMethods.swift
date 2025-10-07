// 
//  MobileMessaging+PluginsMethods.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

public extension MobileMessaging {
    
    /**
     Fabric method for Mobile Messaging session.
     This method creates a MobileMessaging instance using application code which was previously used. Used on the plugins side to make early start, if it's possible.
     - won't be possible and `nil` is returned in case if saving application code is disabled (More details here https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Privacy-settings) or SDK wasn't started with application code before.
     - parameter notificationType: Preferable notification types that indicate how the app alerts the user when a push notification arrives
     */
    class func withSavedApplicationCode(notificationType: MMUserNotificationType) -> MobileMessaging? {
        if let applicationCode = MobileMessaging.keychain.applicationCode {
            return withApplicationCode(applicationCode, notificationType: notificationType)
        } else {
            logWarn("Could not start Mobile Messaging with saved application code. App code was never saved before.")
        }
        return nil
    }
    
    /**
     Checks if the application code provided is the same as the saved one.
     - parameter applicationCode: The application code of your Application from Push Portal website.
     */
    class func didApplicationCodeChange(applicationCode: String) -> Bool {
        return applicationCodeChanged(newApplicationCode: applicationCode)
    }
    
    /**
     Retreives application code from keychain
     */
    class func getKeychainApplicationCode() -> String? {
        return MobileMessaging.keychain.applicationCode
    }
}
