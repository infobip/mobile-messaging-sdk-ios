//
//  MMInteractiveCategory.swift
//
//  Created by okoroleva on 21.07.17.
//
//

public final class MMNotificationCategory: NSObject {
	let identifier: String
	let actions: [MMNotificationAction]
	public init?(identifier: String, actions: [MMNotificationAction]) {
		guard !identifier.hasPrefix("mm_") else {
			return nil
		}
		self.identifier = identifier
		self.actions = actions
	}
	
	var uiUserNotificationCategory: UIUserNotificationCategory {
		let category = UIMutableUserNotificationCategory()
		category.identifier = identifier
		category.setActions(actions.map{$0.uiUserNotificationAction}, for: .default)
		category.setActions(actions.map{$0.uiUserNotificationAction}, for: .minimal)
		return category
	}
	
	public override var hash: Int {
		return identifier.hash
	}
	
	public override func isEqual(_ object: Any?) -> Bool {
		guard let obj = object as? MMNotificationCategory else {
			return false
		}
		return identifier == obj.identifier
	}
}

extension Set where Element: MMNotificationCategory {
	var uiUserNotificationCategoriesSet: Set<UIUserNotificationCategory>? {
		return Set<UIUserNotificationCategory>(self.map{$0.uiUserNotificationCategory})
	}
}


public final class MMNotificationAction: NSObject {
	let identifier: String
	let title: String
	let options: [MMNotificationActionOptions]?
	let handlingBlock: (MTMessage, () -> Void) -> Void
	
	public init?(identifier: String, title: String, options: [MMNotificationActionOptions]?, handlingBlock: @escaping (MTMessage, () -> Void) -> Void) {
		guard !identifier.hasPrefix("mm_") else {
			return nil
		}
		self.identifier = identifier
		self.title = title
		self.options = options
		self.handlingBlock = handlingBlock
	}
	
	var uiUserNotificationAction: UIUserNotificationAction {
		let action = UIMutableUserNotificationAction()
		action.identifier = identifier
		action.title = title
		
		if let options = options {
			action.activationMode = options.contains(.foreground) ? .foreground : .background
			action.isDestructive = options.contains(.destructive) ? true : false
			action.isAuthenticationRequired = options.contains(.requireAuthentification) ? true : false
		}
		return action
	}
}

public final class MMNotificationActionOptions : NSObject {
	let rawValue: Int
	init(rawValue: Int) { self.rawValue = rawValue }
	public init(options: [MMNotificationActionOptions]) {
		let totalValue = options.reduce(0) { (total, option) -> Int in
			return total | option.rawValue
		}
		self.rawValue = totalValue
	}
	public func contains(options: MMLogOutput) -> Bool {
		return rawValue & options.rawValue != 0
	}
	public static let foreground = MMNotificationActionOptions(rawValue: 0) //available starting from iOS 9.0
	public static let destructive = MMNotificationActionOptions(rawValue: 1 << 0)
	public static let requireAuthentification = MMNotificationActionOptions(rawValue: 1 << 1)
}



