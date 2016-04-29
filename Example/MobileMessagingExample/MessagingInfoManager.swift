//
//  MessagingInfo.swift
//  MobileMessaging
//
//  Created by okoroleva on 06.04.16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import MobileMessaging

extension NSData {
	var toHexString: String {
		let tokenChars = UnsafePointer<CChar>(self.bytes)
		var tokenString = ""
		for i in 0..<self.length {
			tokenString += String(format: "%02.2hhx", arguments: [tokenChars[i]])
		}
		return tokenString
	}
}

class MessagingInfo : NSObject {
	dynamic var deviceToken: String?
	dynamic var internalId: String?
}

class MessagingInfoManager : NSObject {
    static let sharedInstance = MessagingInfoManager()
    var messagingInfo: MessagingInfo = MessagingInfo()
    private override init() {
        super.init()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleRegistrationUpdatedNotification:", name: MMEventNotifications.kRegistrationUpdated, object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    //MARK: Handle MobileMessaging Notifications
    func handleRegistrationUpdatedNotification(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
            let registrationUserInfo = userInfo[MMEventNotifications.kRegistrationUserInfoKey] as? String else {
                return
        }
        
        messagingInfo.internalId = registrationUserInfo
    }
}
