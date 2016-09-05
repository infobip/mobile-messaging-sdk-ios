//
//  MMAction.swift
//
//  Created by okoroleva on 05.07.16.
//
//

import Foundation

enum MMPredefinedNotificationActionId: String {
	case OpenURL = "open_url"
	case MarkAsSeen = "mark_as_seen"
	case Reply = "reply"
	
	func createInstance(parameters: AnyObject?, resultInfo: [AnyHashable : Any]?) -> MMBaseAction? {
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
	static var actionId: MMPredefinedNotificationActionId {get}
	init?(parameters: AnyObject?, resultInfo: [AnyHashable : Any]?)
	func perform(message: MMMessage, completion: @escaping (Void) -> Void)
}
protocol MMAction: MMBaseAction {
	associatedtype Result: MMActionResult
	static func setActionHandler(handler: @escaping (Result) -> Void)
}

public final class MMActionMarkAsSeen: NSObject, MMAction {
	public typealias Result = MMMarkAsSeenActionResult
	static let actionId = MMPredefinedNotificationActionId.MarkAsSeen
	init?(parameters: AnyObject?, resultInfo: [AnyHashable : Any]?) {
		super.init()
	}
	
	func perform(message: MMMessage, completion: @escaping (Void) -> Void) {
		MobileMessaging.setSeen(messageIds: [message.messageId])
		MMActionsManager.executeActionHandler(result: MMMarkAsSeenActionResult(messageId: message.messageId), actionId: MMActionMarkAsSeen.actionId) {
			completion()
		}
	}
	
	/**
	Method sets handler for action.
	- parameter handler: Handler for action. Will be performed after action predefined activities.
    */
	public static func setActionHandler(handler: @escaping (Result) -> Void) {
		MMActionsManager.setActionHandler(actionType: MMActionMarkAsSeen.self, handler: handler)
	}
}

public final class MMActionReply: NSObject, MMAction {
	public typealias Result = MMReplyActionResult
	static let actionId = MMPredefinedNotificationActionId.Reply
	var text: String?
	init?(parameters: AnyObject?, resultInfo: [AnyHashable : Any]?) {
		if #available(iOS 9.0, *) {
			self.text = resultInfo?[UIUserNotificationActionResponseTypedTextKey] as? String
		}
		super.init()
	}
	
	func perform(message: MMMessage, completion: @escaping (Void) -> Void) {
		let reply = MMReplyActionResult(messageId: message.messageId, text: self.text)
		MMActionsManager.executeActionHandler(result: reply, actionId: MMActionReply.actionId) {
			completion()
		}
	}
	
	public static func setActionHandler(handler: @escaping (Result) -> Void) {
		MMActionsManager.setActionHandler(actionType: MMActionReply.self, handler: handler)
	}
}

public final class MMActionOpenURL: NSObject, MMAction {
	public typealias Result = MMOpenURLActionResult
	static let actionId = MMPredefinedNotificationActionId.OpenURL
	let url: URL
	init?(parameters: AnyObject?, resultInfo: [AnyHashable : Any]?) {
		guard let path = parameters as? String,
		   let url = URL(string: path) else {
			return nil
		}
		self.url = url
		super.init()
	}
	
	func perform(message: MMMessage, completion: @escaping (Void) -> Void) {
		let result = Result(messageId: message.messageId, url: url)
		DispatchQueue.main.async { 
			UIApplication.shared.openURL(self.url)
		}
		MMActionsManager.executeActionHandler(result: result, actionId: MMActionOpenURL.actionId) {
			completion()
		}
	}

	public static func setActionHandler(handler: @escaping (Result) -> Void) {
		MMActionsManager.setActionHandler(actionType: MMActionOpenURL.self, handler: handler)
	}
}

protocol MMActionResult {
	var messageId: String {get}
	var actionId: MMPredefinedNotificationActionId {get}
}

@objc public class MMMarkAsSeenActionResult: NSObject, MMActionResult {
	let actionId = MMPredefinedNotificationActionId.MarkAsSeen
	public let messageId: String
	init(messageId: String) {
		self.messageId = messageId
		super.init()
	}
}

@objc public class MMReplyActionResult: NSObject, MMActionResult {
	let actionId = MMPredefinedNotificationActionId.Reply
	public let messageId: String
	public let text: String?
	init(messageId: String, text: String?) {
		self.messageId = messageId
		self.text = text
		super.init()
	}
}

@objc public class MMOpenURLActionResult: NSObject, MMActionResult {
	let actionId = MMPredefinedNotificationActionId.OpenURL
	public let messageId: String
	public let url: URL
	init(messageId: String, url: URL) {
		self.messageId = messageId
		self.url = url
		super.init()
	}
}
