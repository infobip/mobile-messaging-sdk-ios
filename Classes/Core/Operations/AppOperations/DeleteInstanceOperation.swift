//
//  DeleteInstanceOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 27/11/2018.
//

import Foundation

class DeleteInstanceOperation : Operation {
	let mmContext: MobileMessaging
	let finishBlock: ((UpdateInstanceDataResult) -> Void)?
	var result: UpdateInstanceDataResult = UpdateInstanceDataResult.Cancel
	let pushRegistrationId: String
	let expiredPushRegistrationId: String

	init(pushRegistrationId: String, expiredPushRegistrationId: String, mmContext: MobileMessaging, finishBlock: ((UpdateInstanceDataResult) -> Void)?) {
		self.pushRegistrationId = pushRegistrationId
		self.expiredPushRegistrationId = expiredPushRegistrationId
		self.mmContext = mmContext
		self.finishBlock = finishBlock
	}

	override func execute() {
		guard !isCancelled else {
			MMLogDebug("[DeleteInstanceOperation] cancelled...")
			finish()
			return
		}
		MMLogDebug("[DeleteInstanceOperation] started...")
		sendServerRequestIfNeeded()
	}

	private func sendServerRequestIfNeeded() {
		guard mmContext.apnsRegistrationManager.isRegistrationHealthy else {
			MMLogWarn("[DeleteInstanceOperation] Registration is not healthy. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.InvalidRegistration))
			return
		}

		mmContext.remoteApiProvider.deleteInstance(applicationCode: mmContext.applicationCode, pushRegistrationId: pushRegistrationId, expiredPushRegistrationId: expiredPushRegistrationId) { (result) in
			self.handleResult(result)
			self.finishWithError(result.error)
		}
	}

	private func handleResult(_ result: UpdateInstanceDataResult) {
		self.result = result
		switch result {
		case .Success:
			mmContext.keychain.pushRegId = pushRegistrationId // rewrite expired with actual one
			MMLogDebug("[DeleteInstanceOperation] succeeded")
		case .Failure(let error):
			MMLogError("[DeleteInstanceOperation] sync request failed with error: \(error.orNil)")
		case .Cancel:
			MMLogWarn("[DeleteInstanceOperation] sync request cancelled.")
		}
	}

	override func finished(_ errors: [NSError]) {
		MMLogDebug("[DeleteInstanceOperation] finished with errors: \(errors)")
		finishBlock?(result) //check what to do with errors/
	}
}
