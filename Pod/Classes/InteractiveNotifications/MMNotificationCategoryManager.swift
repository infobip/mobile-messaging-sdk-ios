//
//  PushCategoryManager.swift
//
//  Created by okoroleva on 04.07.16.
//
//

import Foundation

enum MMNotificationCategories : String {
	case ChatMessage = "chatMessage"
	case CouponMessage = "couponMessage"

	var identifier: String {
		return self.rawValue
	}
	
	var buttons: [MMNotificationButton] {
		switch self {
		case .ChatMessage:
			return [
				MMNotificationButton(identifier: MMNotificationButtons.MarkAsSeen,
					title: "Mark as seen", activationMode: .Background, authenticationRequired: false, destructive: false, parameters: nil),
				MMNotificationButton(identifier: MMNotificationButtons.Reply, title: "Reply", activationMode: isIOS9() ? .Background : .Foreground, authenticationRequired: false, destructive: false, parameters: nil, allowsTextInput: true)
			]
		case .CouponMessage:
			return [
				MMNotificationButton(identifier: MMNotificationButtons.Apply, title: "Apply", activationMode: .Foreground, authenticationRequired: false, destructive: false, parameters: nil)
			]
		}
	}
}

enum MMNotificationButtons : String {
	case MarkAsSeen = "markAsSeen"
	case Reply = "reply"
	case Apply = "apply"
	
	func predefinedAction() -> MMPredefinedActions? {
		switch self {
		case .MarkAsSeen: return MMPredefinedActions.MarkAsSeen
		case .Reply: return MMPredefinedActions.Reply
		case .Apply: return nil
		}
	}
}

class MMNotificationButton {
	let identifier : String
	let title : String
	let activationMode : UIUserNotificationActivationMode
	let authenticationRequired : Bool
	let destructive : Bool
	let parameters: [String: AnyObject]?
	
	private var _behavior : Any?
	
	@available(iOS 9.0, *)
	var behavior : UIUserNotificationActionBehavior? {
		get {
			return _behavior as? UIUserNotificationActionBehavior
		}
		set {
			_behavior = newValue
		}
	}
	
	init(identifier: MMNotificationButtons, title: String, activationMode: UIUserNotificationActivationMode, authenticationRequired: Bool, destructive: Bool, parameters: [String: AnyObject]?, allowsTextInput: Bool = false) {
		self.identifier = identifier.rawValue
		self.title = title
		self.activationMode = activationMode
		self.authenticationRequired = authenticationRequired
		self.destructive = destructive
		self.parameters = parameters
		
		if #available(iOS 9.0, *) {
			self.behavior = allowsTextInput ? .TextInput : .Default
		}
	}
}

class MMNotificationCategoryManager {
	
	class func categoriesToRegister() -> Set<UIUserNotificationCategory>? {
		let categoriesToRegister = predefinedCategories.map { (category: MMNotificationCategories) -> UIUserNotificationCategory in
			let notificationActions = category.buttons.map { action -> UIUserNotificationAction in
				return prepareNotificationAction(action)
			}
			
			let userNotificationCategory = UIMutableUserNotificationCategory()
			userNotificationCategory.identifier = category.identifier
			userNotificationCategory.setActions(notificationActions, forContext: .Default)
			userNotificationCategory.setActions(notificationActions, forContext: .Minimal)
			return userNotificationCategory
		}
		return NSSet(array: categoriesToRegister) as? Set<UIUserNotificationCategory>
	}
	
	//MARK: Private
	private static let predefinedCategories: [MMNotificationCategories] = [.ChatMessage, .CouponMessage]
	
	private class func prepareNotificationAction(notificationButton: MMNotificationButton) -> UIUserNotificationAction {
		let inputAction = UIMutableUserNotificationAction()
		inputAction.identifier = notificationButton.identifier
		inputAction.title = notificationButton.title
		inputAction.activationMode = notificationButton.activationMode
		inputAction.authenticationRequired = notificationButton.authenticationRequired
		inputAction.destructive = notificationButton.destructive
		
		if #available(iOS 9.0, *) {
			if let params = notificationButton.parameters {
				inputAction.parameters = params
			}
			if let behavior = notificationButton.behavior {
				inputAction.behavior = behavior
			}
		}
		return inputAction
	}
}
