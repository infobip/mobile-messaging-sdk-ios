//
//  InteractiveMessageAlert.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 23/04/2018.
//

import Foundation

public class InteractiveMessageAlertSettings: NSObject {
	public static var errorPlaceholderText: String = "Sorry, couldn't load the image"
	public static var tintColor = UIColor(red: 0, green: 122, blue: 255, alpha: 1)
	public static var enabled: Bool = true
}

class InteractiveMessageAlert {
	static let sharedInstance = InteractiveMessageAlert()
	
	func cancelAllAlerts() {
		AlertQueue.sharedInstace.cancelAllAlerts()
	}
	
	func showInteractiveAlert(forMessage message: MTMessage, exclusively: Bool) {
		guard
			InteractiveMessageAlertSettings.enabled,
			let text = message.text,
			let categoryId = message.category,
			let category = MobileMessaging.category(withId: categoryId),
			category.actions.first(where: { return $0 is TextInputNotificationAction } ) == nil else
		{
			return
		}
		
		MMLogDebug("Alert for message will be shown: \(message.messageId) text: \(String(describing: message.text))")
		
		let alert = InteractiveMessageAlertController(
			titleText: message.title,
			messageText: text,
			imageURL: message.contentUrl?.safeUrl,
			category: category,
			actionHandler: {
				action in
				MobileMessaging.handleActionWithIdentifier(identifier: action.identifier, message: message, responseInfo: nil, completionHandler: {})
		})
		
		if exclusively {
			AlertQueue.sharedInstace.cancelAllAlerts()
		}
		AlertQueue.sharedInstace.enqueueAlert(alert: alert)
	}
}
