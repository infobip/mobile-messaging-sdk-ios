//
//  MMAction.swift
//
//  Created by okoroleva on 05.07.16.
//
//

import Foundation

enum MMPredefinedActions : String {
	case OpenURL = "open_url"
	case MarkAsSeen = "mark_as_seen"
	case Reply = "reply"
	
	func createInstance(parameters parameters: AnyObject?, resultInfo: [NSObject : AnyObject]?) -> MMBaseAction? {
		var actionType: MMBaseAction.Type
		switch self {
		case .OpenURL: actionType = MMActionOpenURL.self
		case .MarkAsSeen: actionType =  MMActionMarkAsSeen.self
		case .Reply: actionType =  MMActionReply.self
		}
		return actionType.init(parameters: parameters, resultInfo: resultInfo)
	}
}

protocol MMBaseAction {
	static var actionId : MMPredefinedActions {get}
	init?(parameters: AnyObject?, resultInfo: [NSObject : AnyObject]?)
	func perform(message: MMMessage, completion: Void -> Void)
}
protocol MMAction : MMBaseAction {
	associatedtype Result : MMActionResult
	static func setActionHandler(handler: Result -> Void)
}

public final class MMActionMarkAsSeen : NSObject, MMAction {
	public typealias Result = MMMarkAsSeenActionResult
	static let actionId : MMPredefinedActions = .MarkAsSeen
	init?(parameters: AnyObject?, resultInfo: [NSObject : AnyObject]?) {
		super.init()
	}
	
	func perform(message: MMMessage, completion: Void -> Void) {
		MobileMessaging.setSeen([message.messageId])
		MMActionsManager.executeActionHandler(MMMarkAsSeenActionResult(messageId: message.messageId), actionId: MMActionMarkAsSeen.actionId) {
			completion()
		}
	}
	
	/**
	Method sets handler for action.
	- parameter handler: Handler for action. Will be performed after action predefined activities.
   */
	public static func setActionHandler(handler: Result -> Void) {
		MMActionsManager.setActionHandler(MMActionMarkAsSeen.self, handler: handler)
	}
}

public final class MMActionReply : NSObject, MMAction {
	public typealias Result = MMReplyActionResult
	static let actionId : MMPredefinedActions = .Reply
	var text : String?
	init?(parameters: AnyObject?, resultInfo: [NSObject : AnyObject]?) {
		if #available(iOS 9.0, *) {
			self.text = resultInfo?[UIUserNotificationActionResponseTypedTextKey] as? String
		}
		super.init()
	}
	
	func perform(message: MMMessage, completion: Void -> Void) {
		let reply = MMReplyActionResult(messageId: message.messageId, text: self.text)
		MMActionsManager.executeActionHandler(reply, actionId: MMActionReply.actionId) {
			completion()
		}
	}
	
	public static func setActionHandler(handler: Result -> Void) {
		MMActionsManager.setActionHandler(MMActionReply.self, handler: handler)
	}
}

public final class MMActionOpenURL : NSObject, MMAction {
	public typealias Result = MMOpenURLActionResult
	static let actionId : MMPredefinedActions = .OpenURL
	let url: NSURL
	init?(parameters: AnyObject?, resultInfo: [NSObject : AnyObject]?) {
		guard let path = parameters as? String,
		   let url = NSURL(string: path) else {
			return nil
		}
		self.url = url
		super.init()
	}
	
	func perform(message: MMMessage, completion: Void -> Void) {
		let result = Result(messageId: message.messageId, url: url)
		dispatch_async(dispatch_get_main_queue()) {
			UIApplication.sharedApplication().openURL(self.url)
		}
		MMActionsManager.executeActionHandler(result, actionId: MMActionOpenURL.actionId) {
			completion()
		}
	}

	public static func setActionHandler(handler: Result -> Void) {
		MMActionsManager.setActionHandler(MMActionOpenURL.self, handler: handler)
	}
}

protocol MMActionResult {
	var messageId: String {get}
	var actionId : MMPredefinedActions {get}
}

@objc public class MMMarkAsSeenActionResult : NSObject, MMActionResult {
	let actionId : MMPredefinedActions = .MarkAsSeen
	public let messageId: String
	init(messageId: String) {
		self.messageId = messageId
		super.init()
	}
}

@objc public class MMReplyActionResult : NSObject, MMActionResult {
	let actionId : MMPredefinedActions = .Reply
	public let messageId: String
	public let text : String?
	init(messageId: String, text: String?) {
		self.messageId = messageId
		self.text = text
		super.init()
	}
}

@objc public class MMOpenURLActionResult: NSObject, MMActionResult {
	let actionId : MMPredefinedActions = .OpenURL
	public let messageId: String
	public let url: NSURL
	init(messageId: String, url: NSURL) {
		self.messageId = messageId
		self.url = url
		super.init()
	}
}