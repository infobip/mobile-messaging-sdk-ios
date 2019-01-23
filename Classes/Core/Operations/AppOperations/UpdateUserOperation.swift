//
//  SaveUserAttributeOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 01/11/2018.
//

import Foundation

class UpdateUserOperation: Operation {
	let mmContext: MobileMessaging
	let currentUser: UserDataService
	let attributesSet: AttributesSet
	let finishBlock: ((UpdateUserDataResult) -> Void)?
	var result: UpdateUserDataResult = UpdateUserDataResult.Cancel
	let requireResponse: Bool

	init?(attributesSet: AttributesSet, currentUser: UserDataService, mmContext: MobileMessaging, requireResponse: Bool, finishBlock: ((UpdateUserDataResult) -> Void)?) {
		self.currentUser = currentUser
		self.mmContext = mmContext
		self.finishBlock = finishBlock
		self.requireResponse = requireResponse

		if attributesSet.isEmpty {
			MMLogDebug("[UpdateUserOperation] There are no attributes to sync save. Aborting...")
			return nil
		} else {
			self.attributesSet = attributesSet
		}
	}

	override func execute() {
		guard mmContext.currentInstallation.currentDepersonalizationStatus != .pending else {
			MMLogWarn("[UpdateUserOperation] Logout pending. Canceling...")
			finishWithError(NSError(type: MMInternalErrorType.PendingLogout))
			return
		}
		guard !isCancelled else {
			MMLogDebug("[UpdateUserOperation] cancelled...")
			finish()
			return
		}
		MMLogDebug("[UpdateUserOperation] started...")
		sendServerRequestIfNeeded()
	}

	private func sendServerRequestIfNeeded() {
		guard let pushRegistrationId = mmContext.currentInstallation.pushRegistrationId else {
			MMLogWarn("[UpdateUserOperation] There is no registration. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
			return
		}
		guard mmContext.apnsRegistrationManager.isRegistrationHealthy else {
			MMLogWarn("[UpdateUserOperation] Registration is not healthy. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.InvalidRegistration))
			return
		}
		let body = UserDataMapper.requestPayload(with: currentUser, forAttributesSet: attributesSet) ?? [:]

		mmContext.remoteApiProvider.patchUser(applicationCode: mmContext.applicationCode,
											  pushRegistrationId: pushRegistrationId,
											  body: body)
		{ (result) in
			self.handleUserDataUpdateResult(result)
			self.finishWithError(result.error)
		}
	}

	private func handleUserDataUpdateResult(_ result: UpdateUserDataResult) {
		self.result = result
		guard !isCancelled else {
			MMLogDebug("[UpdateUserOperation] cancelled.")
			return
		}

		switch result {
		case .Success:
			currentUser.persist()
			currentUser.resetNeedToSync(attributesSet: attributesSet)
			currentUser.persist()
			UserEventsManager.postUserSyncedEvent(currentUser.dataObject)
			MMLogDebug("[UpdateUserOperation] successfully synced")
		case .Failure(let error):
			MMLogError("[UpdateUserOperation] sync request failed with error: \(error.orNil)")
		case .Cancel:
			MMLogWarn("[UpdateUserOperation] sync request cancelled.")
		}
	}

	override func finished(_ errors: [NSError]) {
		MMLogDebug("[UpdateUserOperation] finished with errors: \(errors)")
		finishBlock?(self.result)
	}
}
