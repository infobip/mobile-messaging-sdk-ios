//
//  DeviceTokenUtils.swift
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
	
		try? url?.setResourceValues(resourceValues)
		return url
	}()
	private static let encoding: String.Encoding = .utf8

	static func isBackupRestorationHappened(with installation: MMInstallation, user: MMUser) -> Bool {
		guard let fileUrl = ReserveCopyRestoratioUtility.fileUrl else {
			return false
		}
		if let _ = try? String.init(contentsOf: fileUrl, encoding: ReserveCopyRestoratioUtility.encoding) {
			return false
		} else if (installation.deviceToken != nil || user.pushRegistrationId != nil) {
			return true
		} else {
			return false
		}
	}

	static func resetBackupRestorationStatus() {
		guard let fileUrl = ReserveCopyRestoratioUtility.fileUrl else {
			return
		}
		let dateString = DateStaticFormatters.ISO8601SecondsFormatter.string(from: Date())
		try? dateString.write(to: fileUrl, atomically: true, encoding: ReserveCopyRestoratioUtility.encoding)
	}
	
	static func cleanupFlag() {
		guard let fileUrl = ReserveCopyRestoratioUtility.fileUrl else {
			return
		}
		try? FileManager.default.removeItem(at: fileUrl)
	}
}
