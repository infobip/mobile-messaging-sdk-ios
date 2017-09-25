//
//  UserNotificationType.swift
//
//  Created by okoroleva on 22.08.17.
//
//

import UserNotifications

public final class UserNotificationType: NSObject {
	let rawValue: Int
	
	init(rawValue: Int) {
		self.rawValue = rawValue
	}
	
	public init(options: [UserNotificationType]) {
		self.rawValue = options.reduce(0) { (total, option) -> Int in
			return total | option.rawValue
		}
	}
	
	public func contains(options: UserNotificationType) -> Bool {
		return rawValue & options.rawValue != 0
	}
	
	public static let none = UserNotificationType(rawValue: 0)
	
	///The ability to display alerts.
	public static let alert = UserNotificationType(rawValue: 1 << 0)
	
	///The ability to update the app’s badge.
	public static let badge = UserNotificationType(rawValue: 1 << 1)
	
	///The ability to play sounds.
	public static let sound = UserNotificationType(rawValue: 1 << 2)
	
	///The ability to display notifications in a CarPlay environment.
	/// - remark: This option is available only for iOS 10+
	@available(iOS 10.0, *)
	public static let carPlay = UserNotificationType(rawValue: 1 << 3)
	
	@available(iOS 10.0, *)
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
	
	@available(iOS, deprecated: 10.0, message: "Use unAuthorizationOptions")
	var uiUserNotificationType: UIUserNotificationType {
		var type: UIUserNotificationType = []
		if contains(options: .alert) {
			type.formUnion(.alert)
		}
		if contains(options: .sound) {
			type.formUnion(.sound)
		}
		if contains(options: .badge) {
			type.formUnion(.badge)
		}
		return type
	}
}
