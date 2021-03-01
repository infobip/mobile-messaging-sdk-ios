//
//  InstallationDataswift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 01/11/2018.
//

import Foundation
import CoreLocation

let installationQueue = MMOperationQueue.newSerialQueue

final class InstallationDataService: MobileMessagingService {
	init(mmContext: MobileMessaging) {
		super.init(mmContext: mmContext, uniqueIdentifier: "InstallationDataService")
	}
	
	func getUniversalInstallationId() -> String {
		let key = "com.mobile-messaging.universal-installation-id"
		if let universalInstallationId = UserDefaults.standard.string(forKey: key) {
			return universalInstallationId
		} else {
			let universalInstallationId = UUID().uuidString
			UserDefaults.standard.set(universalInstallationId, forKey: key)
			return universalInstallationId
		}
	}

	func save(deviceToken: Data, completion: @escaping (NSError?) -> Void) {
		let di = mmContext.dirtyInstallation()
		di.pushServiceToken = deviceToken.mm_toHexString
		di.archiveDirty()
		syncWithServer(completion)
	}

	func save(installationData: Installation, completion: @escaping (NSError?) -> Void) {
		logDebug("saving \(installationData.dictionaryRepresentation)")
		installationData.archiveDirty()
		syncWithServer(completion)
	}

	func syncSystemDataWithServer(completion: @escaping ((NSError?) -> Void)) {
		logDebug("send system data to server...")
		let currentInstallation = mmContext.currentInstallation()
		let dirtyInstallation = mmContext.dirtyInstallation()
		
		if let op = UpdateInstanceOperation(
			currentInstallation: currentInstallation,
			dirtyInstallation: dirtyInstallation,
			registrationPushRegIdToUpdate: currentInstallation.pushRegistrationId,
			mmContext: mmContext,
			requireResponse: false,
			finishBlock: { completion($0)} )
		{
			installationQueue.addOperation(op)
		} else {
			completion(nil)
		}
	}

	func fetchFromServer(completion: @escaping ((Installation, NSError?) -> Void)) {
		logDebug("fetch from server")
		if let op = FetchInstanceOperation(
			currentInstallation: mmContext.currentInstallation(),
			mmContext: mmContext,
			finishBlock: { completion(self.mmContext.resolveInstallation(), $0) })
		{
			installationQueue.addOperation(op)
		} else {
			completion(mmContext.resolveInstallation(), nil)
		}
	}

	func resetRegistration(completion: @escaping (NSError?) -> Void) {
		logDebug("resetting registration...")
		let op = RegistrationResetOperation(mmContext: mmContext, apnsRegistrationManager: mmContext.apnsRegistrationManager, finishBlock: completion)
		installationQueue.addOperation(op)
	}

	func depersonalize(completion: @escaping (_ status: SuccessPending, _ error: NSError?) -> Void) {
		let op = DepersonalizeOperation(mmContext: mmContext, finishBlock: completion)
		op.queuePriority = .veryHigh
		installationQueue.addOperation(op)
	}

	// MARK: - MobileMessagingService protocol
	override func depersonalizeService(_ mmContext: MobileMessaging, completion: @escaping () -> Void) {
		logDebug("log out")

		let ci = mmContext.currentInstallation() //dup
		ci.customAttributes = [:]
		ci.archiveAll()

		completion()
	}

	override func appWillEnterForeground(_ n: Notification) {
		syncWithServer({_ in})
		performDepersonalizeIfNeeded()
	}

	override func geoServiceDidStart(_ n: Notification) {
		syncSystemDataWithServer() { _ in }
	}

	private func performDepersonalizeIfNeeded() {
		if mmContext.internalData().currentDepersonalizationStatus == .pending {
			depersonalize(completion: { _, _ in })
		}
	}

	override func syncWithServer(_ completion: @escaping (NSError?) -> Void) {
		logDebug("sync installation data with server...")

		let ci = mmContext.currentInstallation()
		let di = mmContext.dirtyInstallation()
		if let op = UpdateInstanceOperation(
			currentInstallation: ci,
			dirtyInstallation: di,
			registrationPushRegIdToUpdate: ci.pushRegistrationId,
			mmContext: mmContext,
			requireResponse: false,
			finishBlock: { self.expireIfNeeded(error: $0, completion) })
			??
			CreateInstanceOperation(
				currentInstallation: ci,
				dirtyInstallation: di,
				mmContext: mmContext,
				requireResponse: true,
				finishBlock: { self.expireIfNeeded(error: $0, completion) })
		{
			installationQueue.addOperation(op)
		} else {
			expireIfNeeded(error: nil, completion)
		}
	}

	// MARK: }

	private func expireIfNeeded(error: NSError?, _ completion: @escaping (NSError?) -> Void) {
		if let actualPushRegId = self.mmContext.currentInstallation().pushRegistrationId, let keychainPushRegId = self.mmContext.keychain.pushRegId, actualPushRegId != keychainPushRegId {
			let deleteExpiredInstanceOp = DeleteInstanceOperation(
				pushRegistrationId: actualPushRegId,
				expiredPushRegistrationId: keychainPushRegId,
				mmContext: self.mmContext,
				finishBlock: { completion($0.error) }
			)

			logDebug("Expired push registration id found: \(keychainPushRegId)")
			installationQueue.addOperation(deleteExpiredInstanceOp)
		} else {
			completion(error)
		}
	}
}
