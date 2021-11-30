//
// Created by Andrey Kadochnikov on 31/10/2018.
//

import Foundation

class UserDataService: MobileMessagingService {

	init(mmContext: MobileMessaging) {
		super.init(mmContext: mmContext, uniqueIdentifier: "UserDataService")
	}

    func setInstallation(userInitiated: Bool, withPushRegistrationId pushRegId: String, asPrimary primary: Bool, completion: @escaping ([MMInstallation]?, NSError?) -> Void) {
        assert(!Thread.isMainThread)
		let finish: (NSError?) -> Void = { (error) in
			if error == nil {
				let ins = self.resolveInstallationsAfterPrimaryChange(pushRegId, primary)
				MMUser.modifyAll(with: { user in
					user.installations = ins
				})
			}
			completion(self.mmContext.resolveUser().installations, error)
		}

		if mmContext.currentInstallation().pushRegistrationId == pushRegId {
			let ci = mmContext.currentInstallation()
			ci.isPrimaryDevice = primary
            mmContext.installationService.save(userInitiated: userInitiated, installationData: ci, completion: finish)
		} else {
			guard let authPushRegistrationId = mmContext.currentInstallation().pushRegistrationId else {
				logError("There is no registration. Finishing setting other reg primary...")
				completion(self.mmContext.resolveUser().installations, NSError(type: MMInternalErrorType.NoRegistration))
				return
			}
			let body = ["isPrimary": primary]
            mmContext.remoteApiProvider.patchOtherInstance(applicationCode: mmContext.applicationCode, authPushRegistrationId: authPushRegistrationId, pushRegistrationId: pushRegId, body: body, queue: DispatchQueue.main) { (result) in
				switch result {
				case .Cancel :
					finish(NSError(type: MMInternalErrorType.UnknownError)) // cannot happen!
				default:
					finish(result.error)
				}
			}
		}
	}

    func depersonalizeInstallation(userInitiated: Bool, withPushRegistrationId pushRegId: String, completion: @escaping ([MMInstallation]?, NSError?) -> Void) {
        assert(!Thread.isMainThread)
        let queuedCompletion: ([MMInstallation]?, NSError?) -> Void = { installations, error in
            let completionQueue = userInitiated ? DispatchQueue.main : installationQueue.underlyingQueue!
            completionQueue.async {
                completion(installations, error)
            }
        }
		guard pushRegId != mmContext.currentInstallation().pushRegistrationId else {
			logError("Attempt to depersonalize current installation with inappropriate API. Aborting depersonalizing other oreg...")
            queuedCompletion(mmContext.resolveUser().installations, NSError(type: MMInternalErrorType.CantLogoutCurrentRegistration))
			return
		}
		guard let authPushRegistrationId = mmContext.currentInstallation().pushRegistrationId else {
			logError("There is no registration. Finishing depersonalizing other reg...")
            queuedCompletion(mmContext.resolveUser().installations, NSError(type: MMInternalErrorType.NoRegistration))
			return
		}
        
        mmContext.remoteApiProvider.depersonalize(applicationCode: mmContext.applicationCode, pushRegistrationId: authPushRegistrationId, pushRegistrationIdToDepersonalize: pushRegId, queue: installationQueue.underlyingQueue!) { (result) in

			if result.error == nil {
				let ins = self.resolveInstallationsAfterLogout(pushRegId)
				MMUser.modifyAll(with: { (user) in
					user.installations = ins
				})
			}
            queuedCompletion(self.mmContext.resolveUser().installations, result.error)
		}
	}

    func save(userInitiated: Bool, userData: MMUser, completion: @escaping (NSError?) -> Void) {
        assert(!Thread.isMainThread)
		logDebug("saving \(userData.dictionaryRepresentation)")
		userData.archiveDirty()
        syncWithServer(userInitiated: userInitiated, completion: completion)
	}

	var isChanged: Bool {
		return MMUser.delta != nil
	}

	func resolveInstallationsAfterPrimaryChange(_ pushRegId: String, _ isPrimary: Bool) -> [MMInstallation]? {
        assert(!Thread.isMainThread)
		let ret = mmContext.resolveUser().installations
		if let idx = ret?.firstIndex(where: { $0.isPrimaryDevice == true }) {
			ret?[idx].isPrimaryDevice = false
		}
		if let idx = ret?.firstIndex(where: { $0.pushRegistrationId == pushRegId }) {
			ret?[idx].isPrimaryDevice = isPrimary
		}
		return ret
	}

	func resolveInstallationsAfterLogout(_ pushRegId: String) -> [MMInstallation]? {
        assert(!Thread.isMainThread)
		var ret = mmContext.resolveUser().installations
		if let idx = ret?.firstIndex(where: { $0.pushRegistrationId == pushRegId }) {
			ret?.remove(at: idx)
		}
		return ret
	}

    func personalize(userInitiated: Bool, forceDepersonalize: Bool, userIdentity: MMUserIdentity, userAttributes: MMUserAttributes?, completion: @escaping (NSError?) -> Void) {
        assert(!Thread.isMainThread)
		let du = mmContext.dirtyUser()
		UserDataMapper.apply(userIdentity: userIdentity, to: du)
		if let userAttributes = userAttributes {
			UserDataMapper.apply(userAttributes: userAttributes, to: du)
		}
		du.archiveDirty()

		let op = PersonalizeOperation(
            userInitiated: userInitiated,
			forceDepersonalize: forceDepersonalize,
			userIdentity: userIdentity,
			userAttributes: userAttributes,
			mmContext: mmContext,
			finishBlock: { completion($0) })

		op.queuePriority = .veryHigh
		installationQueue.addOperation(op)

	}

    func fetchFromServer(userInitiated: Bool, completion: @escaping (MMUser, NSError?) -> Void) {
        assert(!Thread.isMainThread)
		logDebug("fetch from server")
		let op = FetchUserOperation(
            userInitiated: userInitiated,
			currentUser: mmContext.currentUser(),
			dirtyUser: mmContext.dirtyUser(),
			mmContext: mmContext,
			finishBlock: { completion(self.mmContext.resolveUser(), $0) })
		
		installationQueue.addOperation(op)
	}

	// MARK: - MobileMessagingService protocol {
	override func depersonalizeService(_ mmContext: MobileMessaging, completion: @escaping () -> Void) {
        assert(!Thread.isMainThread)
		logDebug("depersonalizing...")
		MMUser.empty.archiveAll()
		completion()
	}

	override func appWillEnterForeground(_ completion: @escaping () -> Void) {
        assert(!Thread.isMainThread)
        syncWithServer(userInitiated: false) {_ in completion() }
	}

	override func mobileMessagingDidStart(_ completion: @escaping () -> Void) {
        assert(!Thread.isMainThread)
        syncWithServer(userInitiated: false) {_ in completion() }
	}
    
    override func mobileMessagingWillStop(_ completion: @escaping () -> Void) {
        assert(!Thread.isMainThread)
        MMUser.cached.reset()
        completion()
    }

    func syncWithServer(userInitiated: Bool, completion: @escaping (NSError?) -> Void) {
        assert(!Thread.isMainThread)
		logDebug("sync user data with server")
		if let op = UpdateUserOperation(
            userInitiated: userInitiated,
			currentUser: mmContext.currentUser(),
			dirtyUser: mmContext.dirtyUser(),
			mmContext: mmContext,
			requireResponse: false,
			finishBlock: { completion($0) })
		{
			installationQueue.addOperation(op)
		} else {
			completion(nil)
		}
	}
}
