//
// Created by Goran Tomasic on 07/10/2016.
//

import Foundation

enum VersionNumbersComparisonError: Error {
	case invalidParameters
}
extension String {
	static func compareVersionNumbers(_ lhs: String, _ rhs: String) throws -> ComparisonResult {
		let significantComponentsNumber = 3
		let lhsComps = lhs.components(separatedBy: ".")
		let rhsComps = rhs.components(separatedBy: ".")
		if lhsComps.count != significantComponentsNumber || rhsComps.count != significantComponentsNumber {
			throw VersionNumbersComparisonError.invalidParameters
		}
		for i in 0..<significantComponentsNumber {
			guard let lInt = Int(lhsComps[i]), let rInt = Int(rhsComps[i]) else {
				throw VersionNumbersComparisonError.invalidParameters
			}
			
			if lInt < rInt {
				return .orderedAscending
			} else if lInt > rInt {
				return .orderedDescending
			}
		}
		return .orderedSame
	}
}

class VersionManager: NamedLogger {
	var lastCheckDate : Date?
	let defaultTimeout: Double = 60 * 60 * 24 // a day
	let mmContext: MobileMessaging
	
	init(mmContext: MobileMessaging) {
		self.mmContext = mmContext
		self.lastCheckDate = UserDefaults.standard.object(forKey: Consts.VersionCheck.lastCheckDateKey) as? Date
	}
	
	func validateVersion(_ completion: (() -> Void)? = nil) {
		logDebug("started...")
		
		guard lastCheckDate == nil || (lastCheckDate?.addingTimeInterval(defaultTimeout).compare(MobileMessaging.date.now) != ComparisonResult.orderedDescending) else
		{
			self.waitUntilItsTime()
			completion?()
			return
		}
		
        mmContext.remoteApiProvider.fetchRecentLibraryVersion(applicationCode: mmContext.applicationCode, pushRegistrationId: mmContext.currentInstallation().pushRegistrationId, queue: mmContext.queue) {
			self.handleResult(result: $0)
			completion?()
		}
	}
	
	func shouldShowNewVersionWarning(onlineVersion: String, localVersion: String) -> Bool {
		return (try? String.compareVersionNumbers(onlineVersion, localVersion) == .orderedDescending) ?? false
	}
	
	func showNewVersionWarning(localVersion: String, response: LibraryVersionResponse) {
		// Make sure that this is displayed in the console (this code can easily execute before the devs set up the logging in the MM_ methods)
		let warningMessage = "\n****\n\tMobileMessaging SDK version \(response.libraryVersion) is available. You are currently using the \(localVersion) version.\n\tWe recommend using the latest version.\n\tYou can update using 'pod update' or by downloading the latest version at: \(response.updateUrl)\n****\n"
		if MobileMessaging.logger?.logLevel == MMLogLevel.Off {
			NSLog(warningMessage)
		} else {
			MMLogWarn(warningMessage)
		}
	}
	
	func waitUntilItsTime() {
		logDebug("There's no need to check the library version at this time.")
	}
	
	func handleUpToDateCase() {
		logDebug("Your MobileMessaging library is up to date.")
		// save the date only if our version is the new one. Otherwise, we warn the dev in the console every time until he/she updates
		self.lastCheckDate = MobileMessaging.date.now
		UserDefaults.standard.set(self.lastCheckDate, forKey: Consts.VersionCheck.lastCheckDateKey)
		UserDefaults.standard.synchronize()
	}

	func handleResult(result: LibraryVersionResult) {
		if let response = result.value {
            if shouldShowNewVersionWarning(onlineVersion: response.libraryVersion, localVersion: MMVersion.mobileMessagingVersion) {
                showNewVersionWarning(localVersion: MMVersion.mobileMessagingVersion, response: response)
			} else {
				handleUpToDateCase()
			}
		} else {
			logError("An error occurred while trying to validate library version: \(result.error.orNil)")
		}
	}
}
