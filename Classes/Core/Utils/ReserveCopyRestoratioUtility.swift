//
//  ReserveCopyRestoratioUtility.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 12/02/2018.
//

import Foundation

class ReserveCopyRestoratioUtility {
	
	private static let fileUrl: URL? = {
		var url = URL(string: "com.mobile-messaging.database/lastReserveCopyDetectionDate", relativeTo: FileManager.default.urls(for: FileManager.SearchPathDirectory.applicationSupportDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).first)
		
		var resourceValues = URLResourceValues()
		resourceValues.isExcludedFromBackup = true
		do {
			try url?.setResourceValues(resourceValues)
		} catch {
			MMLogError("[Backup restoration utils] failed to set flag attributes: \(error)")
		}
		return url
	}()
	
	private static let encoding: String.Encoding = .utf8

	static func isBackupRestorationHappened(with installation: MMInstallation, user: MMUser) -> Bool {
		guard let fileUrl = ReserveCopyRestoratioUtility.fileUrl else {
			MMLogError("[Backup restoration utils] flag url is invalid")
			return false
		}
		
		let flagValue: String?
		do {
			flagValue = try String.init(contentsOf: fileUrl, encoding: ReserveCopyRestoratioUtility.encoding)
		} catch {
			flagValue = nil
			MMLogError("[Backup restoration utils] failed to read flag: \(error)")
		}
		
		if flagValue != nil  {
			MMLogDebug("[Backup restoration utils] backup restoration has been already detected")
			return false
		} else {
			let dt = installation.deviceToken
			let pregId = user.pushRegistrationId
			if (dt != nil || pregId != nil) {
				MMLogDebug("[Backup restoration utils] detected backup restoration (deviceToken = \(String(describing: dt)), pushRegistrationId = \(String(describing: pregId))")
				return true
			} else {
				MMLogDebug("[Backup restoration utils] backup restoration flag not found nor the active registration exists")
				return false
			}
		}
	}

	static func setFlagThatBackupRestorationHandled() {
		MMLogDebug("[Backup restoration utils] setting backup restoration detected flag")
		guard let fileUrl = ReserveCopyRestoratioUtility.fileUrl else {
			MMLogError("[Backup restoration utils] flag url is invalid")
			return
		}
		let dateString = DateStaticFormatters.ISO8601SecondsFormatter.string(from: Date())
		do {
			try dateString.write(to: fileUrl, atomically: true, encoding: ReserveCopyRestoratioUtility.encoding)
		} catch {
			MMLogError("[Backup restoration utils] failed to write flag: \(error)")
		}
	}
	
	static func cleanupFlag() {
		guard let fileUrl = ReserveCopyRestoratioUtility.fileUrl else {
			MMLogError("[Backup restoration utils] flag url is invalid")
			return
		}
		MMLogError("[Backup restoration utils] removing flag...")
		do {
			try FileManager.default.removeItem(at: fileUrl)
		} catch {
			MMLogError("[Backup restoration utils] failed to remove flag: \(error)")
		}
	}
}
