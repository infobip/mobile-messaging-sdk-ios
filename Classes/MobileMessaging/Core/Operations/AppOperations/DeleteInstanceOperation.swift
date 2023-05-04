//
//  DeleteInstanceOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 27/11/2018.
//

import Foundation

class DeleteInstanceOperation : MMOperation {
	
	let mmContext: MobileMessaging
	let finishBlock: ((UpdateInstanceDataResult) -> Void)?
	var result: UpdateInstanceDataResult = UpdateInstanceDataResult.Cancel
	let pushRegistrationId: String
	let expiredPushRegistrationId: String

    init(userInitiated: Bool, pushRegistrationId: String, expiredPushRegistrationId: String, mmContext: MobileMessaging, finishBlock: ((UpdateInstanceDataResult) -> Void)?) {
		self.pushRegistrationId = pushRegistrationId
		self.expiredPushRegistrationId = expiredPushRegistrationId
		self.mmContext = mmContext
		self.finishBlock = finishBlock
        super.init(isUserInitiated: userInitiated)
		self.addCondition(HealthyRegistrationCondition(mmContext: mmContext))
	}

	override func execute() {
		guard !isCancelled else {
			logDebug("cancelled...")
			finish()
			return
		}
		logDebug("started...")
		performRequest()
	}

	private func performRequest() {
        mmContext.remoteApiProvider.deleteInstance(applicationCode: mmContext.applicationCode, pushRegistrationId: pushRegistrationId, expiredPushRegistrationId: expiredPushRegistrationId, queue: self.underlyingQueue) { (result) in
			self.handleResult(result)
			self.finishWithError(result.error)
		}
	}

	private func handleResult(_ result: UpdateInstanceDataResult) {
        assert(!Thread.isMainThread)
		self.result = result
		switch result {
		case .Success:
			mmContext.keychain.pushRegId = pushRegistrationId // rewrite expired with actual one
			logDebug("succeeded")
		case .Failure(let error):
			logError("sync request failed with error: \(error.orNil)")
		case .Cancel:
			logWarn("sync request cancelled.")
		}
	}

	override func finished(_ errors: [NSError]) {
        assert(userInitiated == Thread.isMainThread)
		logDebug("finished with errors: \(errors)")
		finishBlock?(result) //check what to do with errors/
	}
}
