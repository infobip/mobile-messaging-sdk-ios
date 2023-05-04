//
//  MMInteractiveCategory.swift
//
//  Created by okoroleva on 21.07.17.
//
//

import UserNotifications

@objcMembers
public final class MMNotificationCategory: NSObject {
	///The category identifier passed in a `MM_MTMessage` object
	public let identifier: String
	
	///Actions in the order to be displayed for available contexts.
	/// - remark: If there are more than four action objects in the array, the notification displays only the first four. When displaying banner notifications, the system displays only the first two actions.
	public let actions: [MMNotificationAction]
	
	///Options indicating how to handle notifications associated with category.
	public let options: [MMNotificationCategoryOptions]
	
	///The intent identifier strings, which defined in Intents framework, that you want to associate with notifications of this category.
	/// - remark: Intent identifier may be useful for SiriKit support.
	public let intentIdentifiers: [String]
	
	///Initializes the `MMNotificationCategory`
	/// - parameter identifier: category identifier. "mm_" prefix is reserved for Mobile Messaging ids and cannot be used as a prefix.
	/// - parameter actions: Actions in the order to be displayed for available contexts.
	/// - parameter options: Options indicating how to handle notifications associated with category. Supported only for iOS 10+.
	/// - parameter intentIdentifiers: The intent identifier strings, which defined in Intents framework, that you want to associate with notifications of this category. Supported only for iOS 10+.
	public init?(identifier: String, actions: [MMNotificationAction], options: [MMNotificationCategoryOptions]?, intentIdentifiers: [String]?) {
		guard !identifier.hasPrefix(NotificationCategoryConstants.categoryNamePrefix) else {
			return nil
		}
		self.identifier = identifier
		self.actions = actions
		self.options = options ?? []
		self.intentIdentifiers = intentIdentifiers ?? []
	}
	
	public init?(dictionary: [String: Any]) {
		guard let actions = (dictionary[NotificationCategoryConstants.actions] as? [[String: Any]])?.compactMap(MMNotificationAction.makeAction), !actions.isEmpty, let identifier = dictionary[NotificationCategoryConstants.identifier] as? String else
		{
			return nil
		}
		self.actions = actions
		self.identifier = identifier
		self.options = []
		self.intentIdentifiers = []
	}

	var unUserNotificationCategory: UNNotificationCategory {
		var categoryOptions: UNNotificationCategoryOptions = []
		categoryOptions.insert(.customDismissAction)
		if options.contains(.allowInCarPlay) {
			categoryOptions.insert(.allowInCarPlay)
		}
		return UNNotificationCategory(identifier: identifier, actions: actions.map{$0.unUserNotificationAction}, intentIdentifiers: intentIdentifiers, options: categoryOptions)
	}
	
	public override var hash: Int {
		return identifier.hashValue
	}
	
	public override func isEqual(_ object: Any?) -> Bool {
		guard let obj = object as? MMNotificationCategory else {
			return false
		}
		return identifier == obj.identifier
	}
}

@objcMembers
public final class MMNotificationCategoryOptions : NSObject {
	let rawValue: Int
	
	init(rawValue: Int) {
		self.rawValue = rawValue
	}
	
	public init(options: [MMNotificationCategoryOptions]) {
		self.rawValue = options.reduce(0) { (total, option) -> Int in
			return total | option.rawValue
		}
	}
	
	public func contains(options: MMNotificationCategoryOptions) -> Bool {
		return rawValue & options.rawValue != 0
	}
		
	// Whether notifications of this category should be allowed in CarPlay
	/// - remark: This option is available only for iOS 10+
	public static let allowInCarPlay = MMNotificationCategoryOptions(rawValue: 1 << 0)
}

extension Set where Element: MMNotificationCategory {
	var unNotificationCategories: Set<UNNotificationCategory>? {
		return Set<UNNotificationCategory>(self.map{ $0.unUserNotificationCategory })
	}
}

struct NotificationCategories {
	static let path: String? = MobileMessaging.resourceBundle.path(forResource: NotificationCategoryConstants.plistName, ofType: "plist")

    static var predefinedCategories: Set<MMNotificationCategory>? {
		if let path = path, let categories = NSArray(contentsOfFile: path) as? [[String: Any]] {
			return Set(categories.compactMap(MMNotificationCategory.init))
		} else {
			return nil
		}
	}
}

struct NotificationCategoryConstants {
	static let categoryNamePrefix = "mm_"
	static let identifier = "identifier"
	static let actions = "actions"
	static let plistName = "PredefinedNotificationCategories"
}

