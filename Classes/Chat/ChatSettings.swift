//
//  ChatSettings.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 07/11/2017.
//

import Foundation
import WebKit

public class ChatSettings: NSObject {
	
    public static let sharedInstance = ChatSettings()
    
    func postAppearanceChangedNotification() {
		NotificationCenter.default.post(name: NSNotification.Name(rawValue: "com.mobile-messaging.chat.settings.updated"), object: self)
	}
	
	public var title: String? { didSet { postAppearanceChangedNotification() } }
	
	public var sendButtonTintColor: UIColor? { didSet { postAppearanceChangedNotification() } }
	
	public var navBarItemsTintColor: UIColor? { didSet { postAppearanceChangedNotification() } }
	
	public var navBarColor: UIColor? { didSet { postAppearanceChangedNotification() } }
	
	public var navBarTitleColor: UIColor? { didSet { postAppearanceChangedNotification() } }
	
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
    }
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
		objects.forEach { obj in
			if let appearanceObject = obj.value as? ChatSettingsApplicable {
				appearanceObject.applySettings()
			}
		}
	}
}
