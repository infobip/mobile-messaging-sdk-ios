//
//  MMNotificationAction.swift
//
//  Created by okoroleva on 27.07.17.
//
//

public final class MMNotificationAction: NSObject {
	public let identifier: String
	public let title: String
	public let options: [MMNotificationActionOptions]?
	
	///Initializes the `MMNotificationAction`
	/// - parameter identifier: action identifier. "mm_" prefix is reserved for Mobile Messaging ids and cannot be used as a prefix.
	/// - parameter title: Title of the button which will be displayed.
	/// - parameter options: Options with which to perform the action.
	public init?(identifier: String, title: String, options: [MMNotificationActionOptions]?) {
		guard !identifier.hasPrefix(NotificationActionKeys.mm_prefix) else {
			return nil
		}
		self.identifier = identifier
		self.title = title
		self.options = options
	}
	
	init?(dictionary: [String: Any]) {
		guard let identifier = dictionary[NotificationActionKeys.identifier] as? String,
			let title = dictionary[NotificationActionKeys.title] as? String,
			let title_localization_key = dictionary[NotificationActionKeys.title_localization_key] as? String else {
				return nil
		}
		
		var _options = [MMNotificationActionOptions]()
		if let foreground = dictionary[NotificationActionKeys.foreground] as? Bool, foreground {
			_options.append(.foreground)
		}
		if let authRequired = dictionary[NotificationActionKeys.authenticationRequired] as? Bool, authRequired {
			_options.append(.authenticationRequired)
		}
		if let destructive = dictionary[NotificationActionKeys.destructive] as? Bool, destructive {
			_options.append(.destructive)
		}
		
		self.identifier = identifier
		self.title = MMLocalization.localizedString(forKey: title_localization_key, defaultString: title)
		self.options = _options
	}
	
	var uiUserNotificationAction: UIUserNotificationAction {
		let action = UIMutableUserNotificationAction()
		action.identifier = identifier
		action.title = title
		
		if let options = options {
			action.activationMode = options.contains(.foreground) ? .foreground : .background
			action.isDestructive = options.contains(.destructive) ? true : false
			action.isAuthenticationRequired = options.contains(.authenticationRequired) ? true : false
		}
		return action
	}
	
	public override var hash: Int {
		return identifier.hash
	}
	
	public override func isEqual(_ object: Any?) -> Bool {
		guard let obj = object as? MMNotificationAction else {
			return false
		}
		return identifier == obj.identifier
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
	
	///Causes the launch of the application.
	public static let foreground = MMNotificationActionOptions(rawValue: 0)
	
	///Marks the action button as destructive.
	public static let destructive = MMNotificationActionOptions(rawValue: 1 << 0)
	
	///Requires the device to be unlocked.
	/// - remark: If the action options contains `.foreground`, then the action is considered as requiring authentication automatically.
	public static let authenticationRequired = MMNotificationActionOptions(rawValue: 1 << 1)
}

struct NotificationActionKeys {
	static let identifier = "identifier"
	static let title = "title"
	static let title_localization_key = "title_localization_key"
	static let foreground = "foreground"
	static let authenticationRequired = "authenticationRequired"
	static let destructive = "destructive"
	static let mm_prefix = "mm_"
}
