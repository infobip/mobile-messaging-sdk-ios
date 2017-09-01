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
		guard let scheme = url.scheme,
			supportedSchemes.contains(scheme) else {
				print("Scheme \(String(describing: url.scheme)) not supported")
				return false
		}
		
		guard let viewControllerType = supportedViewControllers.first(where: {url.pathComponents.contains($0.deeplinkIdentifier)}) as? UIViewController.Type else {
			print("Unable to find deeplink-compatible view controller for deeplink: \(url.path)")
			return false
		}
		
		let viewController = viewControllerType.init()
		if let viewController = viewController as? DeeplinkLandingViewController,
			let message = message {
			viewController.handle(message: message)
		}
		
		UIApplication.shared.keyWindow?.visibleViewController?.present(viewController, animated: false)
		
		return true
	}
}

