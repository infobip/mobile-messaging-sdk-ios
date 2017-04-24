//
//  MMDefaultMessageHandling.swift
//
//  Created by Andrey K. on 15/09/16.
//
//

import Foundation

@objc public protocol MessageHandling {
	/// This callback is triggered after the new message is received. Default behaviour is implemented by `MMDefaultMessageHandling` class.
	func didReceiveNewMessage(message: MTMessage)
}

public class MMDefaultMessageHandling: MessageHandling {
	@objc public func didReceiveNewMessage(message: MTMessage) {
		switch message.deliveryMethod {
		case .pull, .generatedLocally:
			self.presentLocalNotificationAlert(with: message)
		case .push, .undefined:
			break
		}
	}
	
	func presentLocalNotificationAlert(with message: MTMessage) {
		UILocalNotification.mm_presentLocalNotification(with: message)
	}
}
