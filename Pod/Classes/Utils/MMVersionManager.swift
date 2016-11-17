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
class MMVersionManager {
	static let shared = MMVersionManager()
	var remoteApiQueue: MMRemoteAPIQueue
	
	private let kLastCheckDateKey = "MMLibrary-LastCheckDateKey"
	private let lastCheckDate : Date?
	
	init?() {
		guard let remoteUrl = MobileMessaging.sharedInstance?.remoteAPIBaseURL,
			  let appCode = MobileMessaging.sharedInstance?.applicationCode else {
				return nil
		}
		
		lastCheckDate = UserDefaults.standard.object(forKey: kLastCheckDateKey) as? Date
		remoteApiQueue = MMRemoteAPIQueue(baseURL: remoteUrl, applicationCode: appCode)
	}
	
	func validateVersion() {
		MMLogDebug("[Checking versions] started...")
		
		var shouldCheckVersion = true
		
		if lastCheckDate != nil {
			let advancedDate = lastCheckDate?.addingTimeInterval(60 /* to minutes */ * 60 /* to hours */ * 24 /* to days */)
			shouldCheckVersion = (advancedDate?.compare(Date()) == ComparisonResult.orderedAscending)
		}
		
		guard shouldCheckVersion else {
			MMLogDebug("There's no need to check the library version at this time.")
			return
		}
		
		let handlingQueue = OperationQueue.mm_newSerialQueue
		
		handlingQueue.addOperation(LibraryVersionFetchingOperation(remoteAPIQueue: remoteApiQueue) { [unowned self] (result: MMLibraryVersionResult) in
			if result.error == nil {
				if let onlineVersion = result.value?.libraryVersion,
					let updateUrl = result.value?.updateUrl {
					do {
						if try String.compareVersionNumbers(onlineVersion, libVersion) == .orderedDescending {
							// Make sure that this is displayed in the console (this code can easily execute before the devs set up the logging in the MM_ methods)
							let warningMessage = "\n****\n\tMobileMessaging SDK version \(onlineVersion) is available. You are currently using the \(libVersion) version.\n\tWe recommend using the latest version.\n\tYou can update using 'pod update' or by downloading the latest version at: \(updateUrl)\n****\n"
							if MobileMessaging.logger.logLevel == MMLogLevel.Off {
								NSLog(warningMessage)
							} else {
								MMLogWarn(warningMessage)
							}
						} else {
							MMLogDebug("[Checking versions] Your MobileMessaging library is up to date.")
							
							// save the date only if our version is the new one. Otherwise, we warn the dev in the console every time until he/she updates
							UserDefaults.standard.set(Date(), forKey: self.kLastCheckDateKey)
							UserDefaults.standard.synchronize()
						}
					} catch {
						MMLogError("[Checking versions] Exceprion arose while comparing versions")
					}
				}
			} else {
				if let error = result.error {
					MMLogError("[Checking versions] An error occurred while trying to validate library version: \(error)")
				}
			}
		})
	}
	
}
