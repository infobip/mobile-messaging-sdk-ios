//
//  UserNotificationType.swift
//
//  Created by okoroleva on 22.08.17.
//
//

import UserNotifications

@objcMembers
public final class MMUserNotificationType: NSObject, ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = MMUserNotificationType
	let rawValue: Int

	public override var description: String {
		return String(rawValue, radix: 2)
	}

	init(rawValue: Int) {
		self.rawValue = rawValue
	}
	
    public convenience init(arrayLiteral: ArrayLiteralElement...) {
        self.init(options: arrayLiteral)
    }

	public init(options: [MMUserNotificationType]) {
		self.rawValue = options.reduce(0) { (total, option) -> Int in
			return total | option.rawValue
		}
	}
	
	public func contains(options: MMUserNotificationType) -> Bool {
		return rawValue & options.rawValue != 0
	}
	
	public static let none = MMUserNotificationType(rawValue: 0)
	
	///The ability to display alerts.
	public static let alert = MMUserNotificationType(rawValue: 1 << 0)
	
	///The ability to update the app’s badge.
	public static let badge = MMUserNotificationType(rawValue: 1 << 1)
	
	///The ability to play sounds.
	public static let sound = MMUserNotificationType(rawValue: 1 << 2)
	
	///The ability to display notifications in a CarPlay environment.
	/// - remark: This option is available only for iOS 10+
	public static let carPlay = MMUserNotificationType(rawValue: 1 << 3)
    
	var unAuthorizationOptions: UNAuthorizationOptions {
		var options: UNAuthorizationOptions = []
		if contains(options: .alert) {
			options.formUnion(.alert)
		}
		if contains(options: .sound) {
			options.formUnion(.sound)
		}
		if contains(options: .badge) {
			options.formUnion(.badge)
		}
		if contains(options: .carPlay) {
			options.formUnion(.carPlay)
		}
		return options
	}
    
    public override var hash : Int {
        return rawValue
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        if let other = object as? MMUserNotificationType {
            return self.rawValue == other.rawValue
        } else {
            return false
        }
    }
}
