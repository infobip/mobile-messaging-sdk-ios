//
//  ApnsRegistrationManager.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 12/02/2018.
//

import Foundation
import UserNotifications

class ApnsRegistrationManager: NamedLogger {
	let mmContext: MobileMessaging
    
    init(mmContext: MobileMessaging) {
		self.mmContext = mmContext
	}
	
	func unregister(userInitiated: Bool) {
        guard userInitiated == true || mmContext.unregisteringForRemoteNotificationsDisabled == false else {
            logDebug("Canceling unregistering with args userInitiated \(userInitiated), unregisteringForRemoteNotificationsDisabled \(mmContext.unregisteringForRemoteNotificationsDisabled)")
            return
        }
		if MobileMessaging.application.isRegisteredForRemoteNotifications {
			MobileMessaging.application.unregisterForRemoteNotifications()
		}
	}
    
    func stop() {
        readyToRegisterForNotifications = false
        unregister(userInitiated: false)
        UNUserNotificationCenter.current().delegate = nil
    }
	
    func registerForRemoteNotifications(userInitiated: Bool) {
        guard userInitiated == true || mmContext.registeringForRemoteNotificationsDisabled == false else {
            logDebug("Canceling registration with args userInitiated \(userInitiated), registeringForRemoteNotificationsDisabled \(mmContext.registeringForRemoteNotificationsDisabled)")
            return
        }
        
        switch mmContext.internalData().currentDepersonalizationStatus {
        case .success, .undefined:
            break
        case .pending:
            logDebug("Canceling registration due to pending depersonalize state. Retry will be done on depersonalize state change automatically...")
            return
        }
        
        logDebug("Registering...")
        
        registerNotificationSettings(application: MobileMessaging.application, userNotificationType: mmContext.userNotificationType)
        
        if mmContext.currentInstallation().pushServiceToken == nil {
            if MobileMessaging.application.isRegisteredForRemoteNotifications {
                logDebug("The application is registered for remote notifications but MobileMessaging lacks of device token. Unregistering...")
                unregister(userInitiated: userInitiated)
            }
            setRegistrationIsHealthy()
        }
        
        // we always registering to avoid cases when the device token stored in SDK database becomes outdated (i.e. due to iOS reserve copy restoration). `didRegisterForRemoteNotificationsWithDeviceToken` will return us the most relevant token.
        MobileMessaging.application.registerForRemoteNotifications()
        readyToRegisterForNotifications = true
	}
	
    func didRegisterForRemoteNotificationsWithDeviceToken(userInitiated: Bool, token: Data, completion: @escaping (NSError?) -> Void) {
        
        guard readyToRegisterForNotifications else {
            logDebug("MobileMessaging is not ready to register for notifications")
            completion(nil)
            return
        }

		let tokenStr = token.mm_toHexString
		logInfo("Application did register with device token \(tokenStr)")
		
		UserEventsManager.postDeviceTokenReceivedEvent(tokenStr)
		
		// in most cases we either get the same token we registered earlier or we are just starting
		let installation = mmContext.resolveInstallation()
		if installation.pushServiceToken == nil || installation.pushServiceToken == tokenStr {
			setRegistrationIsHealthy()
            updateDeviceToken(userInitiated: userInitiated, token: token, completion: completion)
		} else {
			// let's check if a special healthy flag is true. It may be false only due to iOS reserve copy restoration
			if isRegistrationHealthy == false {
				// if we face the reserve copy restoration we force a new registration
                resetRegistration(userInitiated: userInitiated) { self.updateDeviceToken(userInitiated: userInitiated, token: token, completion: completion) }
			} else { // in other cases it is the APNS changing the device token
                updateDeviceToken(userInitiated: userInitiated, token: token, completion: completion)
			}
		}
	}
	
	func resetRegistration(userInitiated: Bool, completion: @escaping () -> Void) {
        mmContext.installationService.resetRegistration(userInitiated: userInitiated, completion: { _ in completion() })
	}
	
    func updateDeviceToken(userInitiated: Bool, token: Data, completion: @escaping (NSError?) -> Void) {
        mmContext.installationService.save(userInitiated: userInitiated, deviceToken: token, completion: completion)
	}
	
	private var isRegistrationHealthy_cached: Bool?
	/// The attribute shows whether we are sure that the current apns registration is healthy (may receive push, is linked with appropriate people record). May become unhealthy due to iOS reserve copy restoration - so the device token stored (recovered) in local database would not be a working one.
	var isRegistrationHealthy: Bool {
		guard isRegistrationHealthy_cached == nil else {
			return isRegistrationHealthy_cached!
		}
		
		guard let flagUrl = ApnsRegistrationManager.registrationHealthCheckFlagUrl else {
			logError("registration health flag url is invalid")
			return false
		}
		
		let apnsRegistrationHealthyFlagValue: String?
		do {
			apnsRegistrationHealthyFlagValue = try String.init(contentsOf: flagUrl, encoding: ApnsRegistrationManager.encoding)
		} catch {
			apnsRegistrationHealthyFlagValue = nil
			if !error.mm_isNoSuchFile {
				logError("failed to read flag: \(error)")
			}
		}
		
		isRegistrationHealthy_cached = apnsRegistrationHealthyFlagValue != nil
		return isRegistrationHealthy_cached!
	}
	
	func setRegistrationIsHealthy() {
		logDebug("setting healthy flag")
		guard isRegistrationHealthy == false, var flagUrl = ApnsRegistrationManager.registrationHealthCheckFlagUrl else {
			return
		}
		
		do {
			let dateString = DateStaticFormatters.ISO8601SecondsFormatter.string(from: MobileMessaging.date.now)
			try dateString.write(to: flagUrl, atomically: true, encoding: ApnsRegistrationManager.encoding)
			
			var resourceValues = URLResourceValues()
			resourceValues.isExcludedFromBackup = true
			try flagUrl.setResourceValues(resourceValues)
			isRegistrationHealthy_cached = true
		} catch {
			logError("failed to write healthy flag: \(error)")
		}
	}
	
	func cleanup() {
		logDebug("cleaning up...")
		guard let flagUrl = ApnsRegistrationManager.registrationHealthCheckFlagUrl else {
			logError("failed to define urls for cleaning")
			return
		}
		
		do {
			try FileManager.default.removeItem(at: flagUrl)
		} catch {
			if !error.mm_isNoSuchFile {
				logError("failed to remove flag: \(error)")
			}
		}
	}
	
	private static let registrationHealthCheckFlagUrl: URL? = URL(string: "com.mobile-messaging.database/apnsRegistrationHealthyFlag", relativeTo: FileManager.default.urls(for: FileManager.SearchPathDirectory.applicationSupportDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).first)
	
	private static let encoding: String.Encoding = .utf8
	
	private func registerNotificationSettings(application: MMApplication, userNotificationType: MMUserNotificationType) {
        if mmContext.overridingNotificationCenterDeleageDisabled == false {
            UNUserNotificationCenter.current().delegate = UserNotificationCenterDelegate.sharedInstance
        }
		UNUserNotificationCenter.current().requestAuthorization(options: userNotificationType.unAuthorizationOptions) { (granted, error) in
			UserEventsManager.postNotificationCenterAuthRequestFinished(granted: granted, error: error)
			guard granted else {
				self.logDebug("Authorization for notification options wasn't granted with error: \(error.debugDescription)")
				return
			}
            if let categories = self.mmContext.notificationsInteractionService?.allNotificationCategories?.unNotificationCategories {
				UNUserNotificationCenter.current().setNotificationCategories(categories)
			}
		}
	}
    
    var readyToRegisterForNotifications: Bool = false
}

