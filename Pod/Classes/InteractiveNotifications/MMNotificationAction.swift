//
//  MMNotificationAction.swift
//
//  Created by okoroleva on 27.07.17.
//
//

public final class MMNotificationAction: NSObject {
	public let identifier: String
	public let title: String
	public let options: [MMNotificationActionOptions]
	
	/// Initializes the `MMNotificationAction`
	/// - parameter identifier: action identifier. "mm_" prefix is reserved for Mobile Messaging ids and cannot be used as a prefix.
	/// - parameter title: Title of the button which will be displayed.
	/// - parameter options: Options with which to perform the action.
	public init?(identifier: String, title: String, options: [MMNotificationActionOptions]?) {
		guard !identifier.hasPrefix(NotificationActionKeys.mm_prefix) else {
			return nil
		}
		self.identifier = identifier
		self.title = title
		self.options = options ?? []
	}
	
	init?(dictionary: [String: Any]) {
		guard let identifier = dictionary[NotificationActionKeys.identifier] as? String,
			let title = dictionary[NotificationActionKeys.title] as? String,
			let titleLocalizationKey = dictionary[NotificationActionKeys.titleLocalizationKey] as? String else
		{
			return nil
		}
		
		var opts = [MMNotificationActionOptions]()
		if let isForeground = dictionary[NotificationActionKeys.foreground] as? Bool, isForeground {
			opts.append(.foreground)
		}
		if let isAuthRequired = dictionary[NotificationActionKeys.authenticationRequired] as? Bool, isAuthRequired {
			opts.append(.authenticationRequired)
		}
		if let isDestructive = dictionary[NotificationActionKeys.destructive] as? Bool, isDestructive {
			opts.append(.destructive)
		}
		if let isMoRequired = dictionary[NotificationActionKeys.moRequired] as? Bool, isMoRequired {
			opts.append(.moRequired)
		}
		
		self.identifier = identifier
		self.title = MMLocalization.localizedString(forKey: titleLocalizationKey, defaultString: title)
		self.options = opts
	}
	
	var uiUserNotificationAction: UIUserNotificationAction {
		let action = UIMutableUserNotificationAction()
		action.identifier = identifier
		action.title = title
		action.activationMode = options.contains(.foreground) ? .foreground : .background
		action.isDestructive = options.contains(.destructive)
		action.isAuthenticationRequired = options.contains(.authenticationRequired)
		return action
	}
	
	public override var hash: Int {
		return identifier.hash
	}
	
	public override func isEqual(_ object: Any?) -> Bool {
		guard let object = object as? MMNotificationAction else {
			return false
		}
		return identifier == object.identifier
	}
}

public final class MMNotificationActionOptions : NSObject {
	let rawValue: Int
    
	init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
	public init(options: [MMNotificationActionOptions]) {
        self.rawValue = options.reduce(0) { (total, option) -> Int in
            return total | option.rawValue
        }
	}
    
	public func contains(options: MMLogOutput) -> Bool {
		return rawValue & options.rawValue != 0
	}
	
	/// Causes the launch of the application.
	public static let foreground = MMNotificationActionOptions(rawValue: 0)
	
	/// Marks the action button as destructive.
	public static let destructive = MMNotificationActionOptions(rawValue: 1 << 0)
	
	/// Requires the device to be unlocked.
	/// - remark: If the action options contains `.foreground`, then the action is considered as requiring authentication automatically.
	public static let authenticationRequired = MMNotificationActionOptions(rawValue: 1 << 1)
	
	/// Indicates whether the SDK must generate MO message to report on users interaction.
	public static let moRequired = MMNotificationActionOptions(rawValue: 1 << 2)
}

struct NotificationActionKeys {
	static let identifier = "identifier"
	static let title = "title"
	static let titleLocalizationKey = "titleLocalizationKey"
	static let foreground = "foreground"
	static let authenticationRequired = "authenticationRequired"
	static let moRequired = "moRequired"
	static let destructive = "destructive"
	static let mm_prefix = "mm_"
}
