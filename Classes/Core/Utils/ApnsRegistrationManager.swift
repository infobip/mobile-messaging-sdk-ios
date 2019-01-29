//
//  ApnsRegistrationManager.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 12/02/2018.
//

import Foundation
import UserNotifications

class ApnsRegistrationManager {
	let mmContext: MobileMessaging
	
	init(mmContext: MobileMessaging) {
		self.mmContext = mmContext
	}

	func unregister() {
		if MobileMessaging.application.isRegisteredForRemoteNotifications {
			MobileMessaging.application.unregisterForRemoteNotifications()
		}
	}

	func registerForRemoteNotifications() {
		MMLogDebug("[APNS reg manager] Registering...")

		switch mmContext.currentInstallation.currentDepersonalizationStatus {
		case .success, .undefined:
			break
		case .pending:
			MMLogDebug("[APNS reg manager] canceling due to pending depersonalize state...")
			return
		}

		registerNotificationSettings(application: MobileMessaging.application, userNotificationType: mmContext.userNotificationType)

		if mmContext.currentInstallation.deviceToken == nil {
			if MobileMessaging.application.isRegisteredForRemoteNotifications {
				MMLogDebug("[APNS reg manager] The application is registered for remote notifications but MobileMessaging lacks of device token. Unregistering...")
				unregister()
			}
			setRegistrationIsHealthy()
		}
		
		// we always registering to avoid cases when the device token stored in SDK database becomes outdated (i.e. due to iOS reserve copy restoration). `didRegisterForRemoteNotificationsWithDeviceToken` will return us the most relevant token.
		MobileMessaging.application.registerForRemoteNotifications()
	}
	
	func didRegisterForRemoteNotificationsWithDeviceToken(_ token: Data, completion: @escaping (NSError?) -> Void) {
		let tokenStr = token.mm_toHexString
		MMLogInfo("[APNS reg manager] Application did register with device token \(tokenStr)")

		UserEventsManager.postDeviceTokenReceivedEvent(tokenStr)
		
		// in most cases we either get the same token we registered earlier or we are just starting
		if mmContext.currentInstallation.deviceToken == nil || mmContext.currentInstallation.deviceToken == tokenStr {
			setRegistrationIsHealthy()
			updateDeviceToken(token, completion: completion)
		} else {
			// let's check if a special healthy flag is true. It may be false only due to iOS reserve copy restoration
			if isRegistrationHealthy == false {
				// if we face the reserve copy restoration we force a new registration
				resetRegistration { self.updateDeviceToken(token, completion: completion) }
			} else { // in other cases it is the APNS changing the device token
				updateDeviceToken(token, completion: completion)
			}
		}
	}
	
	func resetRegistration(completion: @escaping () -> Void) {
		mmContext.currentInstallation.resetRegistration(completion: { _ in completion() })
	}
	
	func updateDeviceToken(_ token: Data, completion: @escaping (NSError?) -> Void) {
		mmContext.currentInstallation.save(deviceToken: token, completion: completion)
	}
	
	private var isRegistrationHealthy_cached: Bool?
	/// The attribute shows whether we are sure that the current apns registration is healthy (may receive push, is linked with appropriate people record). May become unhealthy due to iOS reserve copy restoration - so the device token stored (recovered) in local database would not be a working one.
	var isRegistrationHealthy: Bool {
		guard isRegistrationHealthy_cached == nil else {
			return isRegistrationHealthy_cached!
		}
		
		guard let flagUrl = ApnsRegistrationManager.registrationHealthCheckFlagUrl else {
			MMLogError("[APNS reg manager] registration health flag url is invalid")
			return false
		}
		
		let apnsRegistrationHealthyFlagValue: String?
		do {
			apnsRegistrationHealthyFlagValue = try String.init(contentsOf: flagUrl, encoding: ApnsRegistrationManager.encoding)
		} catch {
			apnsRegistrationHealthyFlagValue = nil
			if !error.mm_isNoSuchFile {
				MMLogError("[APNS reg manager] failed to read flag: \(error)")
			}
		}
		
		isRegistrationHealthy_cached = apnsRegistrationHealthyFlagValue != nil
		return isRegistrationHealthy_cached!
	}
	
	func setRegistrationIsHealthy() {
		MMLogDebug("[APNS reg manager] setting healthy flag")
		guard isRegistrationHealthy == false, var flagUrl = ApnsRegistrationManager.registrationHealthCheckFlagUrl else {
			return
		}
		
		do {
			let dateString = DateStaticFormatters.ISO8601SecondsFormatter.string(from: Date())
			try dateString.write(to: flagUrl, atomically: true, encoding: ApnsRegistrationManager.encoding)
			
			var resourceValues = URLResourceValues()
			resourceValues.isExcludedFromBackup = true
			try flagUrl.setResourceValues(resourceValues)
			isRegistrationHealthy_cached = true
		} catch {
			MMLogError("[APNS reg manager] failed to write healthy flag: \(error)")
		}
	}
	
	func cleanup() {
		MMLogDebug("[APNS reg manager] cleaning up...")
		guard let flagUrl = ApnsRegistrationManager.registrationHealthCheckFlagUrl else {
			MMLogError("[APNS reg manager] failed to define urls for cleaning")
			return
		}
		
		do {
			try FileManager.default.removeItem(at: flagUrl)
		} catch {
			if !error.mm_isNoSuchFile {
				MMLogError("[APNS reg manager] failed to remove flag: \(error)")
			}
		}
	}
	
	private static let registrationHealthCheckFlagUrl: URL? = URL(string: "com.mobile-messaging.database/apnsRegistrationHealthyFlag", relativeTo: FileManager.default.urls(for: FileManager.SearchPathDirectory.applicationSupportDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).first)
	
	private static let encoding: String.Encoding = .utf8
	
	private func registerNotificationSettings(application: MMApplication, userNotificationType: UserNotificationType) {
		if #available(iOS 10.0, *) {
			UNUserNotificationCenter.current().delegate = UserNotificationCenterDelegate.sharedInstance
			UNUserNotificationCenter.current().requestAuthorization(options: userNotificationType.unAuthorizationOptions) { (granted, error) in
				guard granted else {
					MMLogDebug("Authorization for notification options wasn't granted with error: \(error.debugDescription)")
					return
				}
				if let categories = NotificationsInteractionService.sharedInstance?.allNotificationCategories?.unNotificationCategories {
					UNUserNotificationCenter.current().setNotificationCategories(categories)
				}
			}
		} else {
			application.registerUserNotificationSettings(UIUserNotificationSettings(types: userNotificationType.uiUserNotificationType, categories: NotificationsInteractionService.sharedInstance?.allNotificationCategories?.uiUserNotificationCategories))
		}
	}
}

