//
//  RegistrationOperation.swift
//
//  Created by Andrey K. on 18/04/16.
//
//

import UIKit
import CoreData

final class SyncRegistrationOperation: Operation {
	let installation: MMInstallation
	let user: MMUser
	let finishBlock: ((NSError?) -> Void)?
	let mmContext: MobileMessaging
	
	init(installation: MMInstallation, user: MMUser, mmContext: MobileMessaging, finishBlock: ((NSError?) -> Void)?) {
		self.installation = installation
		self.user = user
		self.finishBlock = finishBlock
		self.mmContext = mmContext
		super.init()
	}
	
	override func execute() {
		MMLogDebug("[Registration] Started...")
		guard let deviceToken = installation.deviceToken else
		{
			MMLogDebug("[Registration] There is no device token. Finishing...")
			self.finish([NSError(type: MMInternalErrorType.UnknownError)])
			return
		}
		MMLogDebug("[Registration] Posting registration to server...")
		
		let isRegistrationEnabled = installation.isRegistrationStatusNeedSync ? isRegistrationEnabledLocally : nil // send value only if changed
		self.sendRegistration(internalUserId: user.pushRegistrationId, isRegistrationEnabled: isRegistrationEnabled, deviceToken: deviceToken)
	}
	
	private var isRegistrationEnabledLocally: Bool {
		return installation.isPushRegistrationEnabled
	}
	
	private func sendRegistration(internalUserId: String?, isRegistrationEnabled: Bool?, deviceToken: String) {
		let keychainInternalId = mmContext.keychain.internalId
		let expiredInternalId = internalUserId == nil ? keychainInternalId : nil
		mmContext.remoteApiManager.syncRegistration(deviceToken: deviceToken,
		                                            isEnabled: isRegistrationEnabled,
		                                            expiredInternalId: expiredInternalId)
		{ result in
			self.handleRegistrationResult(result)
			self.finishWithError(result.error)
		}
	}
	
	private func handleRegistrationResult(_ result: RegistrationResult) {
		switch result {
		case .Success(let regResponse):
			MMLogDebug("[Registration] Installation updated on server for internal ID \(regResponse.internalId). Updating local version...")
			
			let registrationStatusChanged = regResponse.isEnabled != isRegistrationEnabledLocally
			if regResponse.internalId != user.pushRegistrationId {
				// this is to force system data sync for the new registration
				installation.systemDataHash = 0
			}
			user.pushRegistrationId = regResponse.internalId
			installation.isPushRegistrationEnabled = regResponse.isEnabled
			installation.resetNeedToSync()
			guard !isCancelled else {
				return
			}
			user.persist()
			installation.persist()
			
			if registrationStatusChanged {
				self.mmContext.updateRegistrationEnabledSubservicesStatus(isPushRegistrationEnabled: regResponse.isEnabled)
			}
			
			mmContext.keychain.internalId = regResponse.internalId
			
			NotificationCenter.mm_postNotificationFromMainThread(name: MMNotificationRegistrationUpdated, userInfo: [MMNotificationKeyRegistrationInternalId: regResponse.internalId])
		case .Failure(let error):
			MMLogError("[Registration] request failed with error: \(String(describing: error))")
		case .Cancel:
			MMLogError("[Registration] request cancelled.")
		}
	}
	
	override func finished(_ errors: [NSError]) {
		MMLogDebug("[Registration] finished with errors: \(errors)")
		finishBlock?(errors.first)
	}
}
