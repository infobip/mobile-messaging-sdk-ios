//
//  ChatSettings.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 07/11/2017.
//

import Foundation
import WebKit

public class MMChatSettings: NSObject {
	
    public static let sharedInstance = MMChatSettings()
    
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
    public var backgroungColor: UIColor? { didSet { postAppearanceChangedNotification() } }
    public var errorLabelTextColor: UIColor? { didSet { postAppearanceChangedNotification() } }
    public var errorLabelBackgroundColor: UIColor? { didSet { postAppearanceChangedNotification() } }
    public var advancedSettings: MMAdvancedChatSettings = MMAdvancedChatSettings() { didSet { postAppearanceChangedNotification() } }
    public var multithreadBackButton: UIBarButtonItem?
	
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
        if let background = widget.backgroundColor {
            let color = UIColor(hexString: background)
            if backgroungColor == nil {
                backgroungColor = color
            }
        }
    }
    
    internal static var advSettings: MMAdvancedChatSettings? {
        return MobileMessaging.inAppChat?.settings.advancedSettings
    }
    internal static func getMainFont() -> UIFont {
        return advSettings?.mainFont ?? ComposeBarConsts.kMainFont
    }
    internal static func getCharCountFont() -> UIFont {
        return advSettings?.charCountFont ?? ComposeBarConsts.kCharCountFont
    }
    internal static func getMainTextColor() -> UIColor {
        return advSettings?.mainTextColor ?? ComposeBarConsts.kMainTextColor
    }
    internal static func getMainPlaceholderTextColor() -> UIColor {
        return advSettings?.mainPlaceholderTextColor ?? ComposeBarConsts.kMainPlaceholderTextColor
    }
    internal static func getSendButtonIcon() -> UIImage? {
        return advSettings?.sendButtonIcon ?? ComposeBarConsts.kSendButtonIcon
    }    
    internal static func getAttachmentButtonIcon() -> UIImage? {
        return advSettings?.attachmentButtonIcon ?? ComposeBarConsts.kAttachmentButtonIcon
    }

}

public class MMAdvancedChatSettings: NSObject {
    public var textContainerTopMargin: CGFloat         = ComposeBarConsts.kTextContainerTopMargin
    public var textContainerBottomMargin: CGFloat      = ComposeBarConsts.kTextContainerBottomMargin
    public var textContainerLeftPadding: CGFloat       = ComposeBarConsts.kTextContainerLeftPadding
    public var textContainerRightPadding: CGFloat      = ComposeBarConsts.kTextContainerRightPadding
    public var textContainerTopPadding: CGFloat        = ComposeBarConsts.kTextContainerTopPadding
    public var textContainerCornerRadius: CGFloat      = ComposeBarConsts.kTextContainerCornerRadius
    public var textViewTopMargin: CGFloat              = ComposeBarConsts.kTextViewTopMargin
    public var placeholderHeight: CGFloat              = ComposeBarConsts.kPlaceholderHeight
    public var placeholderSideMargin: CGFloat          = ComposeBarConsts.kPlaceholderSideMargin
    public var placeholderTopMargin: CGFloat           = ComposeBarConsts.kPlaceholderTopMargin
    public var buttonHeight: CGFloat                   = ComposeBarConsts.kButtonHeight
    public var buttonTouchableOverlap: CGFloat         = ComposeBarConsts.kButtonTouchableOverlap
    public var buttonRightMargin: CGFloat              = ComposeBarConsts.kButtonRightMargin
    public var buttonBottomMargin: CGFloat             = ComposeBarConsts.kButtonBottomMargin
    public var utilityButtonWidth: CGFloat             = ComposeBarConsts.kUtilityButtonWidth
    public var utilityButtonHeight: CGFloat            = ComposeBarConsts.kUtilityButtonHeight
    public var utilityButtonBottomMargin: CGFloat      = ComposeBarConsts.kUtilityButtonBottomMargin
    public var initialHeight: CGFloat                  = ComposeBarConsts.kInitialHeight
    public var mainTextColor: UIColor                  = ComposeBarConsts.kMainTextColor
    public var mainPlaceholderTextColor: UIColor       = ComposeBarConsts.kMainPlaceholderTextColor
    public var textInputBackgroundColor: UIColor       = .clear
    public var inputContainerBackgroundColor: UIColor  = .white
    public var sendButtonIcon: UIImage?                = ComposeBarConsts.kSendButtonIcon
    public var attachmentButtonIcon: UIImage?          = ComposeBarConsts.kAttachmentButtonIcon
    public var isLineSeparatorHidden: Bool             = ComposeBarConsts.kIsLineSeparatorHidden
    public var mainFont: UIFont?                       = ComposeBarConsts.kMainFont
    public var charCountFont: UIFont?                  = ComposeBarConsts.kCharCountFont
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
            self.backgroungColor = UIColor(hexString: backgroundColor)
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

