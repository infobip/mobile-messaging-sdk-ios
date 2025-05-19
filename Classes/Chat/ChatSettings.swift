//
//  ChatSettings.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 07/11/2017.
//

import Foundation
import WebKit

public protocol MMPropertyLoopable: NSObject
{
    func allProperties() throws -> [String: Any]
    func reversedColors()
}

public extension MMPropertyLoopable
{
    func allProperties() throws -> [String: Any] {
        var result: [String: Any] = [:]
        let mirror = Mirror(reflecting: self)
        guard let style = mirror.displayStyle, style == .struct || style == .class else {
            throw NSError(domain: "com.infobip", code: -1, userInfo: nil)
        }
        for (labelMaybe, valueMaybe) in mirror.children {
            guard let label = labelMaybe else { continue }
            result[label] = valueMaybe
        }
        return result
    }

    func reversedColors() {
        let properties = try? self.allProperties()
        for property in properties ?? [:] {
            if let color = property.value as? UIColor {
                self.setValue(color.inverted, forKey: property.key)
            }
        }
    }
}

private typealias CBC = ComposeBarConsts

@objcMembers
public class MMChatSettings: NSObject, MMPropertyLoopable {
    public static var settings: MMChatSettings = MMChatSettings()
    // You can define your own custom appearance for chat view by accessing a chat settings object.
    public private(set) static var sharedInstance: MMChatSettings {
        get {
            return settings
        }
        set {
            settings = newValue
        }
    }

    func postAppearanceChangedNotification() {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "com.mobile-messaging.chat.settings.updated"), object: self)
    }
    
    public var title: String? { didSet { postAppearanceChangedNotification() } }
    public var sendButtonTintColor: UIColor? { didSet { postAppearanceChangedNotification() } }
    public var navBarItemsTintColor: UIColor? { didSet { postAppearanceChangedNotification() } }
    public var navBarColor: UIColor? { didSet { postAppearanceChangedNotification() } }
    public var navBarTitleColor: UIColor? { didSet { postAppearanceChangedNotification() } }
    public var attachmentPreviewBarsColor: UIColor? { didSet { postAppearanceChangedNotification() } }
    public var attachmentPreviewItemsColor: UIColor? { didSet { postAppearanceChangedNotification() } }
    public var backgroundColor: UIColor? { didSet { postAppearanceChangedNotification() } }
    public var errorLabelTextColor: UIColor? { didSet { postAppearanceChangedNotification() } }
    public var errorLabelBackgroundColor: UIColor? { didSet { postAppearanceChangedNotification() } }
    public var chatInputSeparatorLineColor: UIColor? { didSet { postAppearanceChangedNotification() } }
    public var shouldSetNavBarAppearance: Bool = true
    public var shouldHandleKeyboardAppearance: Bool = true
    public var shouldUseExternalChatInput: Bool = false
    public var widgetTheme: String?

    public var advancedSettings: MMAdvancedChatSettings = MMAdvancedChatSettings() { didSet { postAppearanceChangedNotification() } }

    public var multithreadBackButton: UIBarButtonItem?
    
    internal static var isDarkMode: Bool = false { didSet {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "com.mobile-messaging.chat.settings.updated"), object: MMChatSettings.sharedInstance)
    } }
        
    func update(withChatWidget widget: ChatWidget) {
        if let widgetTitle = widget.title, title == nil {
            title = widgetTitle
        }
        if let primaryColor = widget.primaryColor {
            let color = UIColor(hexString: primaryColor)
            if sendButtonTintColor == nil {
                sendButtonTintColor = color
            }
            if navBarColor == nil {
                navBarColor = color
            }
        }
        if let primaryTextColor = widget.primaryTextColor, navBarTitleColor == nil {
            navBarTitleColor = UIColor(hexString: primaryTextColor)
        }
        if let background = widget.backgroundColor {
            let color = UIColor(hexString: background)
            if backgroundColor == nil {
                backgroundColor = color
            }
        }
    }
    
    internal static var advSettings: MMAdvancedChatSettings? {
        return MMChatSettings.sharedInstance.advancedSettings
    }
    internal static func getMainFont() -> UIFont {
        return advSettings?.mainFont ?? CBC.kMainFont
    }
    internal static func getCharCountFont() -> UIFont {
        return advSettings?.charCountFont ?? CBC.kCharCountFont
    }
    internal static func getMainTextColor() -> UIColor {
        return advSettings?.mainTextColor ?? CBC.kMainTextColor
    }
    internal static func getMainPlaceholderTextColor() -> UIColor {
        return advSettings?.mainPlaceholderTextColor ?? CBC.kMainPlaceholderTextColor
    }
    internal static func getSendButtonIcon() -> UIImage? {
        return advSettings?.sendButtonIcon ?? CBC.kSendButtonIcon
    }
    internal static func getAttachmentButtonIcon() -> UIImage? {
        return advSettings?.attachmentButtonIcon ?? CBC.kAttachmentButtonIcon
    }
    
    public enum ColorTheme {
        case light, dark, auto
    }
}

@objcMembers
public class MMAdvancedChatSettings: NSObject, MMPropertyLoopable {
    public var textContainerTopMargin: CGFloat         = CBC.kTextContainerTopMargin
    public var textContainerBottomMargin: CGFloat      = CBC.kTextContainerBottomMargin
    public var textContainerLeftPadding: CGFloat       = CBC.kTextContainerLeftPadding
    public var textContainerRightPadding: CGFloat      = CBC.kTextContainerRightPadding
    public var textContainerTopPadding: CGFloat        = CBC.kTextContainerTopPadding
    public var textContainerCornerRadius: CGFloat      = CBC.kTextContainerCornerRadius
    public var textViewTopMargin: CGFloat              = CBC.kTextViewTopMargin
    public var placeholderHeight: CGFloat              = CBC.kPlaceholderHeight
    public var placeholderSideMargin: CGFloat          = CBC.kPlaceholderSideMargin
    public var placeholderTopMargin: CGFloat           = CBC.kPlaceholderTopMargin
    public var buttonHeight: CGFloat                   = CBC.kButtonHeight
    public var buttonTouchableOverlap: CGFloat         = CBC.kButtonTouchableOverlap
    public var buttonRightMargin: CGFloat              = CBC.kButtonRightMargin
    public var buttonBottomMargin: CGFloat             = CBC.kButtonBottomMargin
    public var utilityButtonWidth: CGFloat             = CBC.kUtilityButtonWidth
    public var utilityButtonHeight: CGFloat            = CBC.kUtilityButtonHeight
    public var utilityButtonBottomMargin: CGFloat      = CBC.kUtilityButtonBottomMargin
    public var initialHeight: CGFloat                  = CBC.kInitialHeight
    public var mainTextColor: UIColor                  = CBC.kMainTextColor
    public var mainPlaceholderTextColor: UIColor       = CBC.kMainPlaceholderTextColor
    public var textInputBackgroundColor: UIColor       = CBC.kTextInputBackgroundColor
    public var typingIndicatorColor: UIColor           = CBC.kTypingIndicatorColor
    public var sendButtonIcon: UIImage?                = CBC.kSendButtonIcon
    public var attachmentButtonIcon: UIImage?          = CBC.kAttachmentButtonIcon
    public var isLineSeparatorHidden: Bool             = CBC.kIsLineSeparatorHidden
    public var mainFont: UIFont?                       = CBC.kMainFont
    public var charCountFont: UIFont?                  = CBC.kCharCountFont
}

class ChatSettingsManager {
	static let sharedInstance = ChatSettingsManager()
	var objects = Array<Weak<AnyObject>>()
	
	init() {
		
	}
	
	deinit {
		NotificationCenter.default.removeObserver(self)
	}
	
	func register(object: ChatSettingsApplicable) {
		if objects.isEmpty {
			NotificationCenter.default.addObserver(self, selector: #selector(ChatSettingsManager.appearanceUpdated), name: NSNotification.Name(rawValue: "com.mobile-messaging.chat.settings.updated"), object: nil)
		}
		
		objects.append(Weak(value: object))
	}
	
	@objc func appearanceUpdated() {
        DispatchQueue.main.async {
            self.objects.forEach { obj in
                if let appearanceObject = obj.value as? ChatSettingsApplicable {
                    appearanceObject.applySettings()
                }
            }
        }
	}
}

// MARK: Plugins handling
extension MMChatSettings {
    struct Keys {
        static let title = "title"
        static let sendButtonColor = "sendButtonColor"
        static let chatInputSeparatorLineColor = "chatInputSeparatorLineColor"
        static let navigationBarItemsColor = "navigationBarItemsColor"
        static let navigationBarColor = "navigationBarColor"
        static let navigationBarTitleColor = "navigationBarTitleColor"
        static let backgroundColor = "backgroundColor"
        static let attachmentPreviewBarsColor = "attachmentPreviewBarsColor"
        static let attachmentPreviewItemsColor = "attachmentPreviewItemsColor"
        static let errorLabelTextColor = "errorLabelTextColor"
        static let errorLabelBackgroundColor = "errorLabelBackgroundColor"
        static let mainTextColor = "mainTextColor"
        static let mainPlaceholderTextColor = "mainPlaceholderTextColor"
    }

    public func configureWith(rawConfig: [String: AnyObject]) {
        if let title = rawConfig[MMChatSettings.Keys.title] as? String {
            self.title = title
        }
        if let sendButtonColor = rawConfig[MMChatSettings.Keys.sendButtonColor] as? String {
            self.sendButtonTintColor = UIColor(hexString: sendButtonColor)
        }
        if let chatInputSeparatorLineColor = rawConfig[MMChatSettings.Keys.chatInputSeparatorLineColor] as? String {
            self.chatInputSeparatorLineColor = UIColor(hexString: chatInputSeparatorLineColor)
        }
        if let navigationBarItemsColor = rawConfig[MMChatSettings.Keys.navigationBarItemsColor] as? String {
            self.navBarItemsTintColor = UIColor(hexString: navigationBarItemsColor)
        }
        if let navigationBarColor = rawConfig[MMChatSettings.Keys.navigationBarColor] as? String {
            self.navBarColor = UIColor(hexString: navigationBarColor)
        }
        if let navigationBarTitleColor = rawConfig[MMChatSettings.Keys.navigationBarTitleColor] as? String {
            self.navBarTitleColor = UIColor(hexString: navigationBarTitleColor)
        }
        if let backgroundColor = rawConfig[MMChatSettings.Keys.backgroundColor] as? String {
            self.backgroundColor = UIColor(hexString: backgroundColor)
        }
        if let attachmentPreviewBarsColor = rawConfig[MMChatSettings.Keys.attachmentPreviewBarsColor] as? String {
            self.attachmentPreviewBarsColor = UIColor(hexString: attachmentPreviewBarsColor)
        }
        if let attachmentPreviewItemsColor = rawConfig[MMChatSettings.Keys.attachmentPreviewItemsColor] as? String {
            self.attachmentPreviewItemsColor = UIColor(hexString: attachmentPreviewItemsColor)
        }
        if let errorLabelTextColor = rawConfig[MMChatSettings.Keys.errorLabelTextColor] as? String {
            self.errorLabelTextColor = UIColor(hexString: errorLabelTextColor)
        }
        if let errorLabelBackgroundColor = rawConfig[MMChatSettings.Keys.errorLabelBackgroundColor] as? String {
            self.errorLabelBackgroundColor = UIColor(hexString: errorLabelBackgroundColor)
        }
    }
}

extension UIColor {
    var inverted: UIColor? {
        // Invert the color by subtracting each RGB component from 1.0
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return UIColor(red: 1.0 - red, green: 1.0 - green, blue: 1.0 - blue, alpha: alpha)
    }
}

