//
//  MMInteractiveCategory.swift
//
//  Created by okoroleva on 21.07.17.
//
//

import UserNotifications

public final class NotificationCategory: NSObject {
	typealias PredefinedCategoryPlistDict = [String: Any]
	
	///The category identifier passed in a `MTMessage` object
	public let identifier: String
	
	///Actions in the order to be displayed for available contexts.
	/// - remark: If there are more than four action objects in the array, the notification displays only the first four. When displaying banner notifications, the system displays only the first two actions.
	public let actions: [NotificationAction]
	
	///Options indicating how to handle notifications associated with category.
	public let options: [NotificationCategoryOptions]
	
	///The intent identifier strings, which defined in Intents framework, that you want to associate with notifications of this category.
	// - remark: Intent identifier may be useful for SiriKit support.
	public let intentIdentifiers: [String]
	
	///Initializes the `NotificationCategory`
	/// - parameter identifier: category identifier. "mm_" prefix is reserved for Mobile Messaging ids and cannot be used as a prefix.
	/// - parameter actions: Actions in the order to be displayed for available contexts.
	/// - parameter options: Options indicating how to handle notifications associated with category. Supported only for iOS 10+.
	/// - parameter intentIdentifiers: The intent identifier strings, which defined in Intents framework, that you want to associate with notifications of this category. Supported only for iOS 10+.
	public init?(identifier: String, actions: [NotificationAction], options: [NotificationCategoryOptions]?, intentIdentifiers: [String]?) {
		guard !identifier.hasPrefix(NotificationCategoryConstants.categoryNamePrefix) else {
			return nil
		}
		self.identifier = identifier
		self.actions = actions
		self.options = options ?? []
		self.intentIdentifiers = intentIdentifiers ?? []
	}
	
	init?(dictionary: PredefinedCategoryPlistDict) {
		guard let identifier = dictionary[NotificationCategoryConstants.identifier] as? String,
			let actionDicts = (dictionary[NotificationCategoryConstants.actions] as? [[String: Any]]) else
		{
			return nil
		}
		
		self.actions = actionDicts.flatMap(NotificationAction.init)
		self.identifier = identifier
		
		if self.actions.isEmpty {
			return nil
		}
		
		self.options = []
		self.intentIdentifiers = []
	}
	
	@available(iOS, deprecated: 10.0, message: "Use unUserNotificationCategory")
	var uiUserNotificationCategory: UIUserNotificationCategory {
		let category = UIMutableUserNotificationCategory()
		category.identifier = identifier
		let uiUserNotificationActions = actions.map{$0.uiUserNotificationAction}
		category.setActions(uiUserNotificationActions, for: .default)
		category.setActions(uiUserNotificationActions, for: .minimal)
		return category
	}
	
	@available(iOS 10.0, *)
	var unUserNotificationCategory: UNNotificationCategory {
		var categoryOptions: UNNotificationCategoryOptions = []
		if options.contains(.customDismissAction) {
			categoryOptions.insert(.customDismissAction)
		}
		if options.contains(.allowInCarPlay) {
			categoryOptions.insert(.allowInCarPlay)
		}
		return UNNotificationCategory(identifier: identifier, actions: actions.map{$0.unUserNotificationAction}, intentIdentifiers: intentIdentifiers, options: categoryOptions)
	}
	
	public override var hash: Int {
		return identifier.hash
	}
	
	public override func isEqual(_ object: Any?) -> Bool {
		guard let obj = object as? NotificationCategory else {
			return false
		}
		return identifier == obj.identifier
	}
}

public final class NotificationCategoryOptions : NSObject {
	let rawValue: Int
	
	init(rawValue: Int) {
		self.rawValue = rawValue
	}
	
	public init(options: [NotificationCategoryOptions]) {
		self.rawValue = options.reduce(0) { (total, option) -> Int in
			return total | option.rawValue
		}
	}
	
	public func contains(options: NotificationCategoryOptions) -> Bool {
		return rawValue & options.rawValue != 0
	}
	
	// Whether dismiss action should be sent to the delegate
	/// - remark: This option is available only for iOS 10+
	@available(iOS 10.0, *)
	public static let customDismissAction = NotificationCategoryOptions(rawValue: 0)
	
	// Whether notifications of this category should be allowed in CarPlay
	/// - remark: This option is available only for iOS 10+
	@available(iOS 10.0, *)
	public static let allowInCarPlay = NotificationCategoryOptions(rawValue: 1 << 0)
}

extension Set where Element: NotificationCategory {
	@available(iOS, deprecated: 10.0, message: "Use unNotificationCategories")
	var uiUserNotificationCategories: Set<UIUserNotificationCategory>? {
		return Set<UIUserNotificationCategory>(self.map{ $0.uiUserNotificationCategory })
	}
	
	@available(iOS 10.0, *)
	var unNotificationCategories: Set<UNNotificationCategory>? {
		return Set<UNNotificationCategory>(self.map{ $0.unUserNotificationCategory })
	}
}

struct NotificationCategories {
	static var path: String? {
		return Bundle(identifier:"org.cocoapods.MobileMessaging")?.path(forResource: NotificationCategoryConstants.plistName, ofType: "plist")
	}
	static var predefinedCategories: Set<NotificationCategory>? {
		
		if let path = path, let categories = NSArray(contentsOfFile: path) as? [[String: Any]] {
			return Set(categories.flatMap(NotificationCategory.init))
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

