//
//  MMInteractiveCategory.swift
//
//  Created by okoroleva on 21.07.17.
//
//

public final class MMNotificationCategory: NSObject {
	
	///The category identifier passed in a `MTMessage` object
	public let identifier: String
	
	///Actions in the order to be displayed for available contexts.
	/// - remark: If there are more than four action objects in the array, the notification displays only the first four. When displaying banner notifications, the system displays only the first two actions.
	public let actions: [MMNotificationAction]
	
	///Initializes the `MMNotificationCategory`
	/// - parameter identifier: category identifier. "mm_" prefix is reserved for Mobile Messaging ids and cannot be used as a prefix.
	/// - parameter actions: Actions in the order to be displayed for available contexts.
	public init?(identifier: String, actions: [MMNotificationAction]) {
		guard !identifier.hasPrefix(NotificationCategoryConstants.categoryNamePrefix) else {
			return nil
		}
		self.identifier = identifier
		self.actions = actions
	}
	
	init?(dictionary: [String: Any]) {
		guard let identifier = dictionary[NotificationCategoryConstants.identifier] as? String,
			let actionDicts = (dictionary[NotificationCategoryConstants.actions] as? [[String: Any]]) else
		{
			return nil
		}
		
		self.actions = actionDicts.flatMap(MMNotificationAction.init)
		self.identifier = identifier
		
		if self.actions.isEmpty {
			return nil
		}
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
		return Set<UIUserNotificationCategory>(self.map{ $0.uiUserNotificationCategory })
	}
}

struct MMNotificationCategories {
	static var path: String? {
		return Bundle(identifier:"org.cocoapods.MobileMessaging")?.path(forResource: NotificationCategoryConstants.plistName, ofType: "plist")
	}
	static var predefinedCategories: Set<MMNotificationCategory>? {
		
		if let path = path, let categories = NSArray(contentsOfFile: path) as? [[String: Any]] {
			return Set(categories.flatMap(MMNotificationCategory.init))
		}
		return nil
	}
}

struct NotificationCategoryConstants {
	static let categoryNamePrefix = "mm_"
	static let identifier = "identifier"
	static let actions = "actions"
	static let plistName = "PredefinedNotificationCategories"
}

