//
//  NotificationAction.swift
//
//  Created by okoroleva on 27.07.17.
//
//
import UserNotifications

@objcMembers
public class MMNotificationAction: NSObject {
    public static var DismissActionId: String {
        return UNNotificationDismissActionIdentifier
    }
	
	public static var DefaultActionId: String {
		return UNNotificationDefaultActionIdentifier
	}
    
    public static var PrimaryActionId: String {
        return "mm_primary_action_id"
    }
	
	public let identifier: String
	public let title: String
	public let options: [MMNotificationActionOptions]
    public var isTapOnNotificationAlert: Bool {
        return identifier == MMNotificationAction.DefaultActionId
    }
	
	class func makeAction(dictionary: [String: Any]) -> MMNotificationAction? {
		if let _ = dictionary[Consts.Interaction.ActionKeys.textInputActionButtonTitle] as? String, let _ = dictionary[Consts.Interaction.ActionKeys.textInputPlaceholder] as? String {
			return MMTextInputNotificationAction(dictionary: dictionary)
		} else {
			return MMNotificationAction(dictionary: dictionary)
		}
	}
	
	/// Initializes the `MMNotificationAction`
	/// - parameter identifier: action identifier. "mm_" prefix is reserved for Mobile Messaging ids and cannot be used as a prefix.
	/// - parameter title: Title of the button which will be displayed.
	/// - parameter options: Options with which to perform the action.
	convenience public init?(identifier: String, title: String, options: [MMNotificationActionOptions]?) {
		guard !identifier.hasPrefix(Consts.Interaction.ActionKeys.mm_prefix) else {
			return nil
		}
		self.init(actionIdentifier: identifier, title: title, options: options)
	}
	
	init(actionIdentifier: String, title: String, options: [MMNotificationActionOptions]?) {
		self.identifier = actionIdentifier
		self.title = title
		self.options = options ?? []
	}
	
	class func dismissAction(title: String = MMLocalization.localizedString(forKey: "mm_button_cancel", defaultString: "Cancel")) -> MMNotificationAction {
		return MMNotificationAction(actionIdentifier: DismissActionId, title: title, options: nil)
	}
	
	class func openAction(title: String = MMLocalization.localizedString(forKey: "mm_button_open", defaultString: "Open")) -> MMNotificationAction {
		return MMNotificationAction(actionIdentifier: DefaultActionId, title: title, options: [MMNotificationActionOptions.foreground])
	}
    
    class var defaultAction: MMNotificationAction {
        return MMNotificationAction(actionIdentifier: DefaultActionId, title: "", options: nil)
    }
    
    class var primaryAction: MMNotificationAction {
        return MMNotificationAction(actionIdentifier: PrimaryActionId, title: "", options: nil)
    }
	
	var unUserNotificationAction: UNNotificationAction {
		var actionOptions: UNNotificationActionOptions = []
		if options.contains(.foreground) {
			actionOptions.insert(.foreground)
		}
		if options.contains(.destructive) {
			actionOptions.insert(.destructive)
		}
		if options.contains(.authenticationRequired) {
			actionOptions.insert(.authenticationRequired)
		}
		return UNNotificationAction(identifier: identifier, title: title, options: actionOptions)
	}
	
	public override var hash: Int {
		return identifier.hashValue
	}
	
	public override func isEqual(_ object: Any?) -> Bool {
		guard let object = object as? MMNotificationAction else {
			return false
		}
		return identifier == object.identifier
	}
	
	fileprivate init?(dictionary: [String: Any]) {
		guard let identifier = dictionary[Consts.Interaction.ActionKeys.identifier] as? String,
			let title = dictionary[Consts.Interaction.ActionKeys.title] as? String else
		{
			return nil
		}
		
		var opts = [MMNotificationActionOptions]()
		if let isForeground = dictionary[Consts.Interaction.ActionKeys.foreground] as? Bool, isForeground {
			opts.append(.foreground)
		}
		if let isAuthRequired = dictionary[Consts.Interaction.ActionKeys.authenticationRequired] as? Bool, isAuthRequired {
			opts.append(.authenticationRequired)
		}
		if let isDestructive = dictionary[Consts.Interaction.ActionKeys.destructive] as? Bool, isDestructive {
			opts.append(.destructive)
		}
		if let isMoRequired = dictionary[Consts.Interaction.ActionKeys.moRequired] as? Bool, isMoRequired {
			opts.append(.moRequired)
		}
		
		let locTitleKey = dictionary[Consts.Interaction.ActionKeys.titleLocalizationKey] as? String
		self.identifier = identifier
		self.title = MMLocalization.localizedString(forKey: locTitleKey, defaultString: title)
		self.options = opts
	}
}

/// Allows text input from the user
public final class MMTextInputNotificationAction: MMNotificationAction {
    public let textInputActionButtonTitle: String
    public let textInputPlaceholder: String
    
    ///Text which was entered in response to action.
    public var typedText: String?
    
    /// Initializes the `TextInputNotificationAction`
    /// - parameter identifier: action identifier. "mm_" prefix is reserved for Mobile Messaging ids and cannot be used as a prefix.
    /// - parameter title: Title of the button which will be displayed.
    /// - parameter options: Options with which to perform the action.
    /// - parameter textInputActionButtonTitle: Title of the text input action button
    /// - parameter textInputPlaceholder: Placeholder in the text input field.
	public init?(identifier: String, title: String, options: [MMNotificationActionOptions]?, textInputActionButtonTitle: String, textInputPlaceholder: String) {
        guard !identifier.hasPrefix(Consts.Interaction.ActionKeys.mm_prefix) else {
            return nil
        }
        self.textInputActionButtonTitle = textInputActionButtonTitle
        self.textInputPlaceholder = textInputPlaceholder
		super.init(actionIdentifier: identifier, title: title, options: options)
    }
	
	fileprivate override init?(dictionary: [String: Any]) {
		guard let textInputActionButtonTitle = dictionary[Consts.Interaction.ActionKeys.textInputActionButtonTitle] as? String,
			let textInputPlaceholder = dictionary[Consts.Interaction.ActionKeys.textInputPlaceholder] as? String else
		{
			return nil
		}
		
		self.textInputActionButtonTitle = textInputActionButtonTitle
		self.textInputPlaceholder = textInputPlaceholder
		
		super.init(dictionary: dictionary)
	}
    
    override var unUserNotificationAction: UNNotificationAction {
        var actionOptions: UNNotificationActionOptions = []
        if options.contains(.foreground) {
            actionOptions.insert(.foreground)
        }
        if options.contains(.destructive) {
            actionOptions.insert(.destructive)
        }
        if options.contains(.authenticationRequired) {
            actionOptions.insert(.authenticationRequired)
        }
        return UNTextInputNotificationAction(identifier: identifier, title: title, options: actionOptions, textInputButtonTitle: textInputActionButtonTitle, textInputPlaceholder: textInputPlaceholder)
    }
}

@objcMembers
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
	
	/// Indicates whether action is compatible with chat messages. If it is compatible, the action button will be shown in the SDK buil-in chat view.
	public static let chatCompatible = MMNotificationActionOptions(rawValue: 1 << 3)
}
