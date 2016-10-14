//
// Created by Goran Tomasic on 07/10/2016.
//

import Foundation

public class MMVersionManager {
	public static let shared = MMVersionManager()
	
	private let kLastCheckDateKey = "MMLibrary-LastCheckDateKey"
	private let lastCheckDate : NSDate?
	
	private init() {
		lastCheckDate = NSUserDefaults.standardUserDefaults().objectForKey(kLastCheckDateKey) as? NSDate
	}
	
	public func validateVersion() {
		MMLogDebug("Checking MobileMessaging library version..")
		
		guard let remoteUrl = MobileMessaging.sharedInstance?.remoteAPIBaseURL,
			let appCode = MobileMessaging.sharedInstance?.applicationCode else {
				MMLogDebug("Can't validate the library version before the library has been initialised.")
				return
		}
		
		var shouldCheckVersion = true
		
		if lastCheckDate != nil {
			let advancedDate = lastCheckDate?.dateByAddingTimeInterval(60 /* to minutes */ * 60 /* to hours */ * 24 /* to days */)
			shouldCheckVersion = (advancedDate?.compare(NSDate()) == NSComparisonResult.OrderedAscending)
		}
		
		guard shouldCheckVersion else {
			MMLogDebug("There's no need to check the library version at this time.")
			return
		}
		
		let handlingQueue = OperationQueue.mm_newSerialQueue
		let remoteApi = MMRemoteAPIQueue(baseURL: remoteUrl, applicationCode: appCode)
		
		handlingQueue.addOperation(LibraryVersionFetchingOperation(remoteAPIQueue: remoteApi) { [unowned self] (result: MMLibraryVersionResult) in
			if result.error == nil {
				if let onlineVersion = result.value?.libraryVersion,
					let updateUrl = result.value?.updateUrl {
					if onlineVersion != libVersion {
						// Make sure that this is displayed in the console (this code can easily execute before the devs set up the logging in the MM_ methods)
						let warningMessage = "\n****\n\tMobileMessaging SDK \(onlineVersion) is available. You are on  \(libVersion) version.\n\tIt is recommended to use the latest version.\n\tUpdate using 'pod update' or download the latest version at: \(updateUrl)\n****\n"
						if MobileMessaging.logger.logLevel == MMLogLevel.Off {
							NSLog(warningMessage)
						} else {
							MMLogWarn(warningMessage)
						}
					} else {
						MMLogDebug("Your MobileMessaging library is up to date.")
						
						// save the date only if our version is the new one. Otherwise, we warn the dev in the console every time until he/she updates
						NSUserDefaults.standardUserDefaults().setObject(NSDate(), forKey: self.kLastCheckDateKey)
						NSUserDefaults.standardUserDefaults().synchronize()
					}
				}
			} else {
				if let error = result.error {
					MMLogDebug("An error occurred while trying to validate library version: \(error)")
				}
			}
			})
	}
	
}
