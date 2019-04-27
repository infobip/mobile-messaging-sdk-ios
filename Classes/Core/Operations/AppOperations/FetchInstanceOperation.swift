//
//  FetchInstanceOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 09/11/2018.
//

import Foundation

class FetchInstanceOperation : Operation {
	let mmContext: MobileMessaging
	let currentInstallation: Installation
	let finishBlock: ((FetchInstanceDataResult) -> Void)?
	var result: FetchInstanceDataResult = FetchInstanceDataResult.Cancel
	let pushRegistrationId: String

	init?(currentInstallation: Installation, mmContext: MobileMessaging, finishBlock: ((FetchInstanceDataResult) -> Void)?) {
		self.currentInstallation = currentInstallation
		self.mmContext = mmContext
		self.finishBlock = finishBlock
		if let pushRegistrationId = currentInstallation.pushRegistrationId {
			self.pushRegistrationId = pushRegistrationId
		} else {
			MMLogDebug("[FetchInstanceOperation] There is no registration. Abortin...")
			return nil
		}
	}

	override func execute() {
		guard !isCancelled else {
			MMLogDebug("[FetchInstanceOperation] cancelled...")
			finish()
			return
		}
		MMLogDebug("[FetchInstanceOperation] started...")
		sendServerRequestIfNeeded()
	}

	private func sendServerRequestIfNeeded() {
		guard mmContext.apnsRegistrationManager.isRegistrationHealthy else {
			MMLogWarn("[FetchInstanceOperation] Registration is not healthy. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.InvalidRegistration))
			return
		}

		mmContext.remoteApiProvider.getInstance(applicationCode: mmContext.applicationCode, pushRegistrationId: pushRegistrationId) { (result) in
			self.handleResult(result)
			self.finishWithError(result.error)
		}
	}

	private func handleResult(_ result: FetchInstanceDataResult) {
		self.result = result
		guard !isCancelled else {
			MMLogDebug("[FetchInstanceOperation] cancelled.")
			return
		}
		switch result {
		case .Success(let responseInstallation):

			responseInstallation.archiveAll()

			MMLogDebug("[FetchInstanceOperation] successfully synced")
		case .Failure(let error):
			MMLogError("[FetchInstanceOperation] sync request failed with error: \(error.orNil)")
			mmContext.apiErrorHandler.handleApiError(error: error)
		case .Cancel:
			MMLogWarn("[FetchInstanceOperation] sync request cancelled.")
		}
	}

	override func finished(_ errors: [NSError]) {
		MMLogDebug("[FetchInstanceOperation] finished with errors: \(errors)")
		finishBlock?(result) //check what to do with errors/
	}
}
