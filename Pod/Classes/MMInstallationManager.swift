//
//  MMInstallationManager.swift
//  Pods
//
//  Created by Andrey K. on 18/04/16.
//
//

import Foundation

class MMInstallationManager: MMStoringService {
	//MARK: Internal
	var registrationRemoteAPI: MMRemoteAPIQueue
	lazy var registrationQueue = OperationQueue.newSerialQueue

	
	init(storage: MMCoreDataStorage, registrationRemoteAPI: MMRemoteAPIQueue) {
		self.registrationRemoteAPI = registrationRemoteAPI
		self.emailMsisdnRemoteAPI = MMRemoteAPIQueue(baseURL: registrationRemoteAPI.baseURL, applicationCode: registrationRemoteAPI.applicationCode)
		super.init(storage: storage)
		_currentInstallation = installationObject
	}
	
	func getValueForKey(key: String) -> AnyObject? {
		var result: AnyObject?
		storageContext.performBlockAndWait {
			result = self.installationObject.valueForKey(key)
		}
		return result
	}
	
	func setValueForKey(key: String, value: AnyObject?) {
		storageContext.performBlock {
			self.installationObject.setValueIfDifferent(value, forKey: key)
		}
	}
	
    func syncWithServer(completion: (NSError? -> Void)? = nil) {
        let newRegOp = RegistrationOperation(context: self.storageContext, remoteAPIQueue: registrationRemoteAPI, finishBlock: completion)
        registrationQueue.addOperation(newRegOp)
    }
    
	func updateDeviceToken(token: NSData, completion: (NSError? -> Void)? = nil) {
		let newRegOp = RegistrationOperation(newDeviceToken: token, context: self.storageContext, remoteAPIQueue: registrationRemoteAPI, finishBlock: completion)
		registrationQueue.addOperation(newRegOp)
	}
	
	func saveMsisdn(msisdn: String, completion: (NSError?) -> Void) {
		registrationQueue.addOperation(SetMSISDNOperation(msisdn: msisdn, context: storageContext, remoteAPIQueue: registrationRemoteAPI, finishBlock: completion))
	}
	
	func saveEmail(email: String, completion: (NSError?) -> Void) {
		registrationQueue.addOperation(SetEmailOperation(email: email, context: storageContext, remoteAPIQueue: registrationRemoteAPI, finishBlock: completion))
	}
	
	//MARK: Private
	private var installationObject: InstallationManagedObject {
		if let installation = _currentInstallation {
			return installation
		} else {
			_currentInstallation = fetchOrCreateCurrentInstallation()
			return _currentInstallation!
		}
	}
	private var installationHasChanges: Bool {
		return installationObject.changedValues().count > 0
	}
	private var emailMsisdnRemoteAPI: MMRemoteAPIQueue
	private var _currentInstallation: InstallationManagedObject?
	
	
	private func fetchOrCreateCurrentInstallation() -> InstallationManagedObject {
		if let existingInstallation = findCurrentInstallation() {
			return existingInstallation
		} else {
			return createInstallation()
		}
	}
	
	private func createInstallation() -> InstallationManagedObject {
		var result: InstallationManagedObject?
		storageContext.performBlockAndWait {
			result = InstallationManagedObject.MR_createEntityInContext(self.storageContext)
			self.storageContext.MR_saveOnlySelfAndWait()
		}
		return result!
	}
	
	private func findCurrentInstallation() -> InstallationManagedObject? {
		var result: InstallationManagedObject?
		storageContext.performBlockAndWait {
			result = InstallationManagedObject.MR_findFirstInContext(self.storageContext)
		}
		return result
	}
	
}