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

class InteractiveMessageAlertManager {
	static let sharedInstance = InteractiveMessageAlertManager()
	
	func cancelAllAlerts() {
		AlertQueue.sharedInstace.cancelAllAlerts()
	}
	
	func showInteractiveAlert(forMessage message: MTMessage, exclusively: Bool) {
		guard InteractiveMessageAlertSettings.enabled, let text = message.text else
		{
			return
		}
		
		MMLogDebug("Alert for message will be shown: \(message.messageId) text: \(message.text.orNil)")
		
		if exclusively {
			cancelAllAlerts()
		}
		AlertQueue.sharedInstace.enqueueAlert(message: message, text: text)
	}
}
