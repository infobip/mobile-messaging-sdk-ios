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
	
	var actions: [MMNotificationAction] {
		switch self {
		case .ChatMessage:
			return [
				MMNotificationAction(actionId: .MarkAsSeen,
					title: "Mark as seen", activationMode: .background, authenticationRequired: false, destructive: false, parameters: nil),
				MMNotificationAction(actionId: .Reply, title: "Reply", activationMode: isIOS9() ? .background : .foreground, authenticationRequired: false, destructive: false, parameters: nil, allowsTextInput: true)
			]
		case .CouponMessage:
			return [
				MMNotificationAction(actionId: .OpenURL, title: "Apply", activationMode: .foreground, authenticationRequired: false, destructive: false, parameters: nil)
			]
		}
	}
}

class MMNotificationAction {
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
	
	init(actionId: MMPredefinedNotificationActionId, title: String, activationMode: UIUserNotificationActivationMode, authenticationRequired: Bool, destructive: Bool, parameters: [String: AnyObject]?, allowsTextInput: Bool = false) {
		self.identifier = actionId.rawValue
		self.title = title
		self.activationMode = activationMode
		self.authenticationRequired = authenticationRequired
		self.destructive = destructive
		self.parameters = parameters
		
		if #available(iOS 9.0, *) {
			self.behavior = allowsTextInput ? .textInput : .default
		}
	}
}

extension UIUserNotificationAction {
	class func withNotificationAction(notificationAction: MMNotificationAction) -> UIUserNotificationAction {
		let inputAction = UIMutableUserNotificationAction()
		inputAction.identifier = notificationAction.identifier
		inputAction.title = notificationAction.title
		inputAction.activationMode = notificationAction.activationMode
		inputAction.isAuthenticationRequired = notificationAction.authenticationRequired
		inputAction.isDestructive = notificationAction.destructive
		
		if #available(iOS 9.0, *) {
			if let params = notificationAction.parameters {
				inputAction.parameters = params
			}
			if let behavior = notificationAction.behavior {
				inputAction.behavior = behavior
			}
		}
		return inputAction
	}
}

class MMNotificationCategoryManager {
	
	class func categoriesToRegister() -> Set<UIUserNotificationCategory>? {
		let categoriesToRegister = predefinedCategories.map { (category: MMNotificationCategories) -> UIUserNotificationCategory in
			let notificationActions = category.actions.map { action -> UIUserNotificationAction in
				return UIUserNotificationAction.withNotificationAction(notificationAction: action)
			}
			
			let userNotificationCategory = UIMutableUserNotificationCategory()
			userNotificationCategory.identifier = category.identifier
			userNotificationCategory.setActions(notificationActions, for: .default)
			userNotificationCategory.setActions(notificationActions, for: .minimal)
			return userNotificationCategory
		}
		return NSSet(array: categoriesToRegister) as? Set<UIUserNotificationCategory>
	}
	
	//MARK: Private
	private static let predefinedCategories: [MMNotificationCategories] = [.ChatMessage, .CouponMessage]
}
