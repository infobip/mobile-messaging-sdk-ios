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
	class func handleLinks(fromMessage message: MTMessage) {
		
		//checking do we have "deeplink" in custom payload
		if let deeplink = message.customPayload?["deeplink"] as? String,
			let deeplinkUrl = URL(string: deeplink) {
			
			_ = openDeeplink(url: deeplinkUrl, withMessage: message)

		// checking do we have "url" in custom payload
		} else if let path = message.customPayload?["url"] as? String,
			let url = URL(string: path) {
		
			UIApplication.shared.keyWindow?.visibleViewController?.present(WebViewController(url: url), animated: false)
		}
	}
	
	class func openDeeplink(url: URL, withMessage message: MTMessage?) -> Bool {
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
	
	class func openViewControllers(fromPathComponents pathComponents: [String], message: MTMessage?) {
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

