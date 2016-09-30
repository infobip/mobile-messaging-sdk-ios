//
//  MMLocalNotifications.swift
//
//  Created by Andrey K. on 12/09/16.
//
//

import Foundation

class MMLocalNotification {
	class func presentLocalNotification(with message: MTMessage) {
		guard !message.isSilent || (message is MMGeoMessage) else {
			return
		}
		let localNotification = UILocalNotification()
		localNotification.alertBody = message.text
		localNotification.soundName = message.sound
		UIApplication.sharedApplication().presentLocalNotificationNow(localNotification)
	}
}