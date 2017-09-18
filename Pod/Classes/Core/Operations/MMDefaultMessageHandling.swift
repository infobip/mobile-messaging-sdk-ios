//
//  MMDefaultMessageHandling.swift
//
//  Created by Andrey K. on 15/09/16.
//
//

import Foundation

@objc public protocol MessageHandling {
	/// This callback is triggered after the new message is received. Default behaviour is implemented by `MMDefaultMessageHandling` class.
	func didReceiveNewMessage(message: MTMessage, completion: (() -> Void)?)
}

public class MMDefaultMessageHandling: MessageHandling {
	@objc public func didReceiveNewMessage(message: MTMessage, completion: (() -> Void)?) {
		switch message.deliveryMethod {
		case .pull, .generatedLocally:
			presentLocalNotificationAlert(with: message, completion: completion)
		case .push, .undefined:
			completion?()
			break
		}
	}
	
	func presentLocalNotificationAlert(with message: MTMessage, completion: (() -> Void)?) {
		LocalNotifications.presentLocalNotification(with: message, completion: completion)
	}
}
