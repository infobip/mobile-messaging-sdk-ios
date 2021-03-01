//
//  CreateInstanceOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 12/11/2018.
//

import Foundation

class CreateInstanceOperation : MMOperation {
	
	let mmContext: MobileMessaging
	let currentInstallation: Installation
	let dirtyInstallation: Installation
	let finishBlock: ((NSError?) -> Void)
	let requireResponse: Bool
	var body: [String: Any]

	init?(currentInstallation: Installation, dirtyInstallation: Installation, mmContext: MobileMessaging, requireResponse: Bool, finishBlock: @escaping ((NSError?) -> Void)) {
		self.mmContext = mmContext
		self.finishBlock = finishBlock
		self.requireResponse = requireResponse
		self.currentInstallation = currentInstallation
		self.dirtyInstallation = dirtyInstallation

		let createInstanceRequestBody = InstallationDataMapper.postRequestPayload(dirtyInstallation: dirtyInstallation, internalData: mmContext.internalData())

		if (createInstanceRequestBody[Attributes.pushServiceToken.rawValue] == nil ||
			createInstanceRequestBody[Consts.SystemDataKeys.pushServiceType] == nil ||
			currentInstallation.pushServiceToken == dirtyInstallation.pushServiceToken ||
			dirtyInstallation.pushServiceToken == nil)
		{
			Self.logWarn("There is no registration data to send. Aborting...")
			return nil
		}

		self.body = createInstanceRequestBody
		super.init()
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
		body["notificationsEnabled"] = true // this is a workaround because registration may happen before user granted any permissions, so that they may be undefined. Forcing true.
		mmContext.remoteApiProvider.postInstance(applicationCode: mmContext.applicationCode, body: body) { (result) in
			self.handleResult(result)
			self.finishWithError(result.error)
		}
	}

	private func handleResult(_ result: FetchInstanceDataResult) {
		guard !isCancelled else {
			logDebug("cancelled.")
			return
		}
		switch result {
		case .Success(let response):
			if response.pushRegistrationId != currentInstallation.pushRegistrationId {
				// this is to force system data sync for the new registration
				let id = mmContext.internalData()
				id.registrationDate = id.registrationDate ?? MobileMessaging.date.now
				id.systemDataHash = 0
				id.archiveCurrent()
			}

			response.archiveAll()

			UserEventsManager.postInstallationSyncedEvent(currentInstallation)
			if mmContext.keychain.pushRegId == nil {
				mmContext.keychain.pushRegId = response.pushRegistrationId
			}
			logDebug("successfully created registration \(String(describing: response.pushRegistrationId))")
		case .Failure(let error):
			logError("sync request failed with error: \(error.orNil)")
		case .Cancel:
			logWarn("sync request cancelled.")
		}
	}

	override func finished(_ errors: [NSError]) {
		logDebug("finished with errors: \(errors)")
		finishBlock(errors.first)
	}
}
