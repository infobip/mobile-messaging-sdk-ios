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

struct MMNotificatoionCategory {
	let categoryId: String
	let buttons : [MMNotificationButton]
	
	static var chatCategory : MMNotificatoionCategory  {
		return MMNotificatoionCategory(categoryId: MMNotificationCategories.ChatMessage.rawValue ,
		                               buttons:[
										MMNotificationButton(identifier: MMNotificationButtons.MarkAsSeen,
											title: "Mark as seen", activationMode: .Background, authenticationRequired: false, destructive: false, parameters: nil),
										MMNotificationButton(identifier: MMNotificationButtons.Reply, title: "Reply", activationMode: isIOS9() ? .Background : .Foreground, authenticationRequired: false, destructive: false, parameters: nil, allowsTextInput: true)
			])
	}
	
	static var couponCategory: MMNotificatoionCategory {
		return MMNotificatoionCategory(categoryId: MMNotificationCategories.CouponMessage.rawValue ,
		                               buttons:[
										MMNotificationButton(identifier: MMNotificationButtons.Apply, title: "Apply", activationMode: .Foreground, authenticationRequired: false, destructive: false, parameters: nil)
			])
	}
}

class MMNotificationCategoryManager {
	
	class func categoriesToRegister() -> Set<UIUserNotificationCategory>? {
		let categoriesToRegister = predefinedCategories.map { (categoryId, category) -> UIUserNotificationCategory in
			let notificationActions = category.buttons.map({ (action) -> UIUserNotificationAction in
				return prepareNotificationAction(action)
			})
			
			let category = UIMutableUserNotificationCategory()
			category.identifier = categoryId.rawValue
			category.setActions(notificationActions, forContext: .Default)
			category.setActions(notificationActions, forContext: .Minimal)
			return category
		}
		return NSSet(array: categoriesToRegister) as? Set<UIUserNotificationCategory>
	}
	
	//MARK: Private
	private static let predefinedCategories: [MMNotificationCategories: MMNotificatoionCategory] = [
		MMNotificationCategories.ChatMessage: MMNotificatoionCategory.chatCategory,
		MMNotificationCategories.CouponMessage: MMNotificatoionCategory.couponCategory
	]
	
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
