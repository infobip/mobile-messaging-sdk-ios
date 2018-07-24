//
//  SyncPrimaryDevice.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 25/06/2018.
//

import Foundation

class SyncPrimaryDeviceOperation : Operation {
	let finishBlock: ((NSError?) -> Void)?
	var result = SeenStatusSendingResult.Cancel
	let installation: MMInstallation
	let mmContext: MobileMessaging
	
	init(mmContext: MobileMessaging, installation: MMInstallation, finishBlock: ((NSError?) -> Void)? = nil) {
		self.finishBlock = finishBlock
		self.installation = installation
		self.mmContext = mmContext
	}
	
	override func execute() {
		guard let pushRegistrationId = mmContext.currentUser.pushRegistrationId, mmContext.apnsRegistrationManager.isRegistrationHealthy else {
			MMLogDebug("[Application instance sync] There is no registration. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
			return
		}
		guard mmContext.apnsRegistrationManager.isRegistrationHealthy else {
			MMLogDebug("[Application instance sync] Registration may be not healthy. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
			return
		}
		if installation.isPrimaryDeviceNeedSync {
			let isPrimaryDevice = installation.isPrimaryDevice
			MMLogDebug("[Application instance sync] putting isPrimaryDevice = \(isPrimaryDevice)...")
			
			mmContext.remoteApiProvider.putInstance(applicationCode: mmContext.applicationCode, pushRegistrationId: pushRegistrationId, isPrimaryDevice: isPrimaryDevice, completion: { (result) in
				switch result {
				case .Success:
					MMLogDebug("[Application instance sync] successfully put instance data")
					self.installation.resetPrimaryDeviceNeedsSync()
					self.installation.persist()
					self.finish()
				case .Failure(let error):
					self.finishWithError(error)
				case .Cancel:
					MMLogDebug("[Application instance sync] cancelled")
					self.finish()
				}
			})
		} else {
			MMLogDebug("[Application instance sync] getting instance...")
			
			mmContext.remoteApiProvider.getInstance(applicationCode: mmContext.applicationCode, pushRegistrationId: pushRegistrationId) { (result) in
				switch result {
				case .Success(let response):
					MMLogDebug("[Application instance sync] successfully get instance data")
					let prevValue = self.installation.isPrimaryDevice
					let newValue = response.primary
					self.installation.isPrimaryDevice = newValue
					self.installation.resetPrimaryDeviceNeedsSync()
					self.installation.persist()
					if (prevValue != newValue) {
						NotificationCenter.mm_postNotificationFromMainThread(name: MMNotificationPrimaryDeviceSettingUpdated, userInfo: nil)
					}
					self.finish()
				case .Failure(let error):
					self.finishWithError(error)
				case .Cancel:
					MMLogDebug("[Application instance sync] cancelled")
					self.finish()
				}
			}
		}
	}
	
	override func finished(_ errors: [NSError]) {
		MMLogDebug("[Application instance sync] finished with errors: \(errors)")
		finishBlock?(errors.first)
	}
}
