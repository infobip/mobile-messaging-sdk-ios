//
//  NotificationAction.swift
//
//  Created by okoroleva on 27.07.17.
//
//
import UserNotifications

@objcMembers
public class NotificationAction: NSObject {
	public let identifier: String
	public let title: String
	public let options: [NotificationActionOptions]
    public var isTapOnNotificationAlert: Bool {
        return identifier == NotificationAction.DefaultActionId
    }
	
	class func makeAction(dictionary: [String: Any]) -> NotificationAction? {
		if #available(iOS 9.0, *), let _ = dictionary[NotificationActionKeys.textInputActionButtonTitle] as? String, let _ = dictionary[NotificationActionKeys.textInputPlaceholder] as? String {
			return TextInputNotificationAction(dictionary: dictionary)
		} else {
			return NotificationAction(dictionary: dictionary)
		}
	}
	
	/// Initializes the `NotificationAction`
	/// - parameter identifier: action identifier. "mm_" prefix is reserved for Mobile Messaging ids and cannot be used as a prefix.
	/// - parameter title: Title of the button which will be displayed.
	/// - parameter options: Options with which to perform the action.
	convenience public init?(identifier: String, title: String, options: [NotificationActionOptions]?) {
		guard !identifier.hasPrefix(NotificationActionKeys.mm_prefix) else {
			return nil
		}
		self.init(actionIdentifier: identifier, title: title, options: options)
	}
	
	init(actionIdentifier: String, title: String, options: [NotificationActionOptions]?) {
		self.identifier = actionIdentifier
		self.title = title
		self.options = options ?? []
	}
	
	@available(iOS 10.0, *)
	class var dismissAction: NotificationAction {
		return NotificationAction(actionIdentifier: UNNotificationDismissActionIdentifier, title: "Dismiss system-defined", options: nil)
	}
    
    static var DefaultActionId: String {
        if #available(iOS 10.0, *) {
            return UNNotificationDefaultActionIdentifier
        } else {
            return "UNNotificationDefaultActionIdentifier"
        }
    }
    
    class var defaultAction: NotificationAction {
        return NotificationAction(actionIdentifier: DefaultActionId, title: "", options: nil)
    }
	
	@available(iOS, deprecated: 10.0, message: "Use unUserNotificationAction")
	var uiUserNotificationAction: UIUserNotificationAction {
		let action = UIMutableUserNotificationAction()
		action.identifier = identifier
		action.title = title
		action.activationMode = options.contains(.foreground) ? .foreground : .background
		action.isDestructive = options.contains(.destructive)
		action.isAuthenticationRequired = options.contains(.authenticationRequired)
		return action
	}
	
	@available(iOS 10.0, *)
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
		return identifier.hash
	}
	
	public override func isEqual(_ object: Any?) -> Bool {
		guard let object = object as? NotificationAction else {
			return false
		}
		return identifier == object.identifier
	}
	
	fileprivate init?(dictionary: [String: Any]) {
		guard let identifier = dictionary[NotificationActionKeys.identifier] as? String,
			let title = dictionary[NotificationActionKeys.title] as? String else
		{
			return nil
		}
		
		var opts = [NotificationActionOptions]()
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
		
		let locTitleKey = dictionary[NotificationActionKeys.titleLocalizationKey] as? String
		self.identifier = identifier
		self.title = MMLocalization.localizedString(forKey: locTitleKey, defaultString: title)
		self.options = opts
	}
}

/// Allows text input from the user
@available(iOS 9.0, *)
public final class TextInputNotificationAction: NotificationAction {
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
	public init?(identifier: String, title: String, options: [NotificationActionOptions]?, textInputActionButtonTitle: String, textInputPlaceholder: String) {
        guard !identifier.hasPrefix(NotificationActionKeys.mm_prefix) else {
            return nil
        }
        self.textInputActionButtonTitle = textInputActionButtonTitle
        self.textInputPlaceholder = textInputPlaceholder
		super.init(actionIdentifier: identifier, title: title, options: options)
    }
	
	fileprivate override init?(dictionary: [String: Any]) {
		guard let textInputActionButtonTitle = dictionary[NotificationActionKeys.textInputActionButtonTitle] as? String,
			let textInputPlaceholder = dictionary[NotificationActionKeys.textInputPlaceholder] as? String else
		{
			return nil
		}
		
		self.textInputActionButtonTitle = textInputActionButtonTitle
		self.textInputPlaceholder = textInputPlaceholder
		
		super.init(dictionary: dictionary)
	}
	
    @available(iOS, deprecated: 10.0, message: "Use unUserNotificationAction")
    override var uiUserNotificationAction: UIUserNotificationAction {
        let action = UIMutableUserNotificationAction()
        action.identifier = identifier
        action.title = title
        action.activationMode = options.contains(.foreground) ? .foreground : .background
        action.isDestructive = options.contains(.destructive)
        action.isAuthenticationRequired = options.contains(.authenticationRequired)
        action.behavior = .textInput
        action.parameters = [UIUserNotificationTextInputActionButtonTitleKey : textInputActionButtonTitle]
        return action
    }
    
    @available(iOS 10.0, *)
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
public final class NotificationActionOptions : NSObject {
	let rawValue: Int
    
	init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
	public init(options: [NotificationActionOptions]) {
        self.rawValue = options.reduce(0) { (total, option) -> Int in
            return total | option.rawValue
        }
	}
    
	public func contains(options: MMLogOutput) -> Bool {
		return rawValue & options.rawValue != 0
	}
	
	/// Causes the launch of the application.
	public static let foreground = NotificationActionOptions(rawValue: 0)
	
	/// Marks the action button as destructive.
	public static let destructive = NotificationActionOptions(rawValue: 1 << 0)
	
	/// Requires the device to be unlocked.
	/// - remark: If the action options contains `.foreground`, then the action is considered as requiring authentication automatically.
	public static let authenticationRequired = NotificationActionOptions(rawValue: 1 << 1)
	
	/// Indicates whether the SDK must generate MO message to report on users interaction.
	public static let moRequired = NotificationActionOptions(rawValue: 1 << 2)
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
	static let textInputActionButtonTitle = "textInputActionButtonTitle"
	static let textInputPlaceholder = "textInputPlaceholder"
}
