//
//  LinksHandler.swift
//  MobileMessagingExample
//
//  Created by okoroleva on 31.08.17.
//

import UIKit
import MobileMessaging

var supportedViewControllers: [DeeplinkLandingViewController.Type] = [RedViewController.self, GreenViewController.self, BlueViewController.self]

class LinksHandler {
	class func handleLinks(fromMessage message: MM_MTMessage) {
		
		//checking do we have "deeplink" in message object
        if let deeplink = message.deeplink {
			_ = openDeeplink(url: deeplink, withMessage: message)
		}
	}
	
	class func openDeeplink(url: URL, withMessage message: MM_MTMessage?) -> Bool {
		let supportedSchemes = ["com.infobip.mobilemessaging"]
		
		//check do we support scheme in the URL
		guard let scheme = url.scheme,
			supportedSchemes.contains(scheme) else {
				print("Scheme \(String(describing: url.scheme)) not supported")
				return false
		}
		
		openViewControllers(fromPathComponents: url.pathComponents, message: message)
		
		return true
	}
	
	class func openViewControllers(fromPathComponents pathComponents: [String], message: MM_MTMessage?) {
		guard !pathComponents.isEmpty else {
			return
		}
		
		let openNext: ([String]) -> Void = { pathComponents in
			var nextPathComponents = pathComponents
			nextPathComponents.removeFirst()
			self.openViewControllers(fromPathComponents: nextPathComponents, message: message)
		}
		
		//check do we have viewController with `deeplinkIdentifier`, provided as URL pathComponent
		guard let viewControllerType = supportedViewControllers.first(where: {pathComponents.first == $0.deeplinkIdentifier}) as? UIViewController.Type else {
			openNext(pathComponents)
			return
		}
		
		//create viewController from type`
		let viewController = viewControllerType.init()
		
		//present viewController modally
		UIApplication.shared.keyWindow?.visibleViewController?.present(viewController, animated: true, completion: {
			if let viewController = viewController as? DeeplinkLandingViewController,
				let message = message {
				viewController.handle(message: message)
			}
			openNext(pathComponents)
		})
	}
}

