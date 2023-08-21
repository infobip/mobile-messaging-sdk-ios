//
//  InstallationDataswift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 01/11/2018.
//

import Foundation
import CoreLocation

let installationDispatchQueue = DispatchQueue(label: "installation-service", qos: DispatchQoS.default, attributes: .concurrent, autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit, target: nil)
let installationQueue = MMOperationQueue.newSerialQueue(underlyingQueue: installationDispatchQueue)

class InstallationDataService: MobileMessagingService {
	init(mmContext: MobileMessaging) {
		super.init(mmContext: mmContext, uniqueIdentifier: "InstallationDataService")
	}
    
    override func mobileMessagingWillStart(_ completion: @escaping () -> Void) {
        assert(!Thread.isMainThread)
        start({_ in completion() })
    }

    override func mobileMessagingWillStop(_ completion: @escaping () -> Void) {
        assert(!Thread.isMainThread)
        MMInstallation.cached.reset()
        installationQueue.cancelAllOperations()
        completion()
    }
    
    override func start(_ completion: @escaping (Bool) -> Void) {
        assert(!Thread.isMainThread)
        super.start(completion)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleError(_:)),
            name: NSNotification.Name(rawValue: MMNotificationAPIError), object: nil)
        syncWithServer(userInitiated: false) { _ in }
    }
	
    @objc func handleError(_ notifictaion: Notification) {
        installationQueue.addOperation {
            if let error = notifictaion.userInfo?[MMNotificationKeyAPIErrorUserInfo] as? NSError, error.mm_code == "NO_REGISTRATION" {
                self.recoverRegistration(userInitiated: false)
            }
        }
    }
    
    func recoverRegistration(userInitiated: Bool) {
        assert(!Thread.isMainThread)
        let dirtyInstallation = mmContext.dirtyInstallation()
        if dirtyInstallation.pushServiceToken != nil && dirtyInstallation.pushRegistrationId != nil {
            logDebug("recovering registration...")
            mmContext.keychain.clear()
            MMInstallation.resetCurrent()
            dirtyInstallation.pushRegistrationId = nil
            dirtyInstallation.archiveDirty()
            syncWithServer(userInitiated: userInitiated) { _ in }
        }
    }
        
	func getUniversalInstallationId() -> String {
        assert(!Thread.isMainThread)
		let key = "com.mobile-messaging.universal-installation-id"
		if let universalInstallationId = UserDefaults.standard.string(forKey: key) {
			return universalInstallationId
		} else {
			let universalInstallationId = UUID().uuidString
			UserDefaults.standard.set(universalInstallationId, forKey: key)
			return universalInstallationId
		}
	}

    func save(userInitiated: Bool, deviceToken: Data, completion: @escaping (NSError?) -> Void) {
        assert(!Thread.isMainThread)
		let di = mmContext.dirtyInstallation()
		di.pushServiceToken = deviceToken.mm_toHexString
		di.archiveDirty()
        syncWithServer(userInitiated: userInitiated, completion)
	}

    func save(userInitiated: Bool, installationData: MMInstallation, completion: @escaping (NSError?) -> Void) {
        assert(!Thread.isMainThread)
		logDebug("saving \(installationData.dictionaryRepresentation)")
		installationData.archiveDirty()
        syncSystemDataWithServer(userInitiated: userInitiated, completion: completion)
	}

    func fetchFromServer(userInitiated: Bool, completion: @escaping ((MMInstallation, NSError?) -> Void)) {
        assert(!Thread.isMainThread)
		logDebug("fetch from server")
		if let op = FetchInstanceOperation(
            userInitiated: userInitiated,
			currentInstallation: mmContext.currentInstallation(),
			mmContext: mmContext,
            finishBlock: { [unowned self] in completion(self.mmContext.resolveInstallation(), $0) })
		{
			installationQueue.addOperation(op)
		} else {
			completion(mmContext.resolveInstallation(), nil)
		}
	}

	func resetRegistration(userInitiated: Bool, completion: @escaping (NSError?) -> Void) {
        assert(!Thread.isMainThread)
		logDebug("resetting registration...")
		let op = RegistrationResetOperation(userInitiated: userInitiated, mmContext: mmContext, apnsRegistrationManager: mmContext.apnsRegistrationManager, finishBlock: completion)
		installationQueue.addOperation(op)
	}

    func depersonalize(userInitiated: Bool, completion: @escaping (_ status: MMSuccessPending, _ error: NSError?) -> Void) {
        assert(!Thread.isMainThread)
        let op = DepersonalizeOperation(userInitiated: userInitiated, mmContext: mmContext, finishBlock: completion)
		op.queuePriority = .veryHigh
		installationQueue.addOperation(op)
	}

	// MARK: - MobileMessagingService protocol
	override func depersonalizeService(_ mmContext: MobileMessaging, completion: @escaping () -> Void) {
        assert(!Thread.isMainThread)
		logDebug("depersonalizing...")

		let ci = mmContext.currentInstallation() //dup
		ci.customAttributes = [:]
		ci.archiveAll()

		completion()
	}
    
    private func syncWithServerAndDepersonalizeIfNeeded(_ completion: @escaping () -> Void) {
        assert(!Thread.isMainThread)
        syncWithServer(userInitiated: false) {_ in
            self.performDepersonalizeIfNeeded(userInitiated: false, completion: completion)
        }
    }
    

	override func appWillEnterForeground(_ completion: @escaping () -> Void) {
        syncWithServerAndDepersonalizeIfNeeded(completion)
	}
    
    override func baseUrlDidChange(_ completion: @escaping () -> Void) {
        syncWithServerAndDepersonalizeIfNeeded(completion)
    }

	override func geoServiceDidStart(_ completion: @escaping () -> Void) {
        assert(!Thread.isMainThread)
		syncSystemDataWithServer(userInitiated: false) { _ in completion() }
	}

    private func performDepersonalizeIfNeeded(userInitiated: Bool, completion: @escaping () -> Void) {
        assert(!Thread.isMainThread)
		if mmContext.internalData().currentDepersonalizationStatus == .pending {
            depersonalize(userInitiated: userInitiated) { _, _ in completion() }
        } else {
            completion()
        }
	}
    
    func syncSystemDataWithServer(userInitiated: Bool, completion: @escaping ((NSError?) -> Void)) {
        assert(!Thread.isMainThread)
        logDebug("send system data to server...")
        let ci = mmContext.currentInstallation()
        let di = mmContext.dirtyInstallation()
        
        if let op = UpdateInstanceOperation(
            userInitiated: userInitiated,
            currentInstallation: ci,
            dirtyInstallation: di,
            registrationPushRegIdToUpdate: ci.pushRegistrationId,
            mmContext: mmContext,
            requireResponse: false,
            finishBlock: { completion($0)} )
        {
            installationQueue.addOperation(op)
        } else {
            completion(nil)
        }
    }

    func syncWithServer(userInitiated: Bool, _ completion: @escaping (NSError?) -> Void) {
        assert(!Thread.isMainThread)
		logDebug("sync installation data with server...")
		let ci = mmContext.currentInstallation()
		let di = mmContext.dirtyInstallation()
        
		if let op = UpdateInstanceOperation(
            userInitiated: userInitiated,
			currentInstallation: ci,
			dirtyInstallation: di,
			registrationPushRegIdToUpdate: ci.pushRegistrationId,
			mmContext: mmContext,
			requireResponse: false,
            finishBlock: { [weak self] in
                guard let _self = self else {
                    completion(nil)
                    return
                }
                _self.expireIfNeeded(userInitiated: userInitiated, error: $0, completion) })
			??
			CreateInstanceOperation(
                userInitiated: userInitiated,
				currentInstallation: ci,
				dirtyInstallation: di,
				mmContext: mmContext,
				requireResponse: true,
                finishBlock: { [weak self] in
                    guard let _self = self else {
                        completion(nil)
                        return
                    }
                    _self.expireIfNeeded(userInitiated: userInitiated, error: $0, completion) })
		{
			installationQueue.addOperation(op)
		} else {
            expireIfNeeded(userInitiated: userInitiated, error: nil, completion)
		}
	}

	// MARK: }

    private func expireIfNeeded(userInitiated: Bool, error: NSError?, _ completion: @escaping (NSError?) -> Void) {
        assert(!Thread.isMainThread)
		if let actualPushRegId = self.mmContext.currentInstallation().pushRegistrationId, let keychainPushRegId = self.mmContext.keychain.pushRegId, actualPushRegId != keychainPushRegId {
			let deleteExpiredInstanceOp = DeleteInstanceOperation(
                userInitiated: userInitiated,
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
