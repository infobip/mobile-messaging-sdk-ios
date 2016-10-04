//
//  UserDataSynchronizationOperation.swift
//
//  Created by Andrey K. on 14/07/16.
//
//

import UIKit
import CoreData

class UserDataSynchronizationOperation: Operation {
	let context: NSManagedObjectContext
	let finishBlock: ((NSError?) -> Void)?
	let remoteAPIQueue: MMRemoteAPIQueue
	
	private var installationObject: InstallationManagedObject!
	private var dirtyAttributes = SyncableAttributesSet(rawValue: 0)
	private let onlyFetching: Bool //TODO: remove for v2 User Data API.
	
	convenience init(fetchingOperationWithContext context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, finishBlock: ((NSError?) -> Void)? = nil) {
		self.init(context: context, remoteAPIQueue: remoteAPIQueue, onlyFetching: true, finishBlock: finishBlock)
	}
	
	convenience init(syncOperationWithContext context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, finishBlock: ((NSError?) -> Void)? = nil) {
		self.init(context: context, remoteAPIQueue: remoteAPIQueue, onlyFetching: false, finishBlock: finishBlock)
	}
	
	private init(context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, onlyFetching: Bool, finishBlock: ((NSError?) -> Void)? = nil) {
		self.context = context
		self.remoteAPIQueue = remoteAPIQueue
		self.finishBlock = finishBlock
		self.onlyFetching = onlyFetching
		
		super.init()
		
		self.addCondition(RegistrationCondition(internalId: MobileMessaging.currentUser?.internalId))
	}
	
	private var installationHasChanges: Bool {
		return installationObject.changedValues().isEmpty == false
	}
	
	override func execute() {
		//TODO: store old valid attributes
		//installationObject.customUserData
		//installationObject.predefinedUserData
		context.performAndWait {
			guard let installation = InstallationManagedObject.MM_findFirstInContext(self.context) else {
				self.finish()
				return
			}
			
			self.installationObject = installation
			self.dirtyAttributes = installation.dirtyAttributesSet
			
			if (self.installationHasChanges) {
				MMLogDebug("User data: saving data locally...")
				self.context.MM_saveToPersistentStoreAndWait()
			} else {
				MMLogDebug("User data: has no changes. No need to save locally.")
			}
			
			self.sendUserDataIfNeeded()
		}
	}
	
	private var userDataChanged: Bool {
		return installationObject.dirtyAttributesSet.intersection(SyncableAttributesSet.userData).isEmpty == false
	}
	
	private var shouldSendRequest: Bool {
		return userDataChanged
	}
	
	private func sendUserDataIfNeeded() {
		if onlyFetching {
			MMLogDebug("User data: fetching from server...")
			self.fetchUserData()
		} else if shouldSendRequest {
			MMLogDebug("User data: sending user data updates to the server...")
			self.sendUserData()
		} else {
			MMLogDebug("User data: has no changes, no need to send to the server.")
			finish()
		}
	}
	
	private func fetchUserData() {
		guard let internalId = MobileMessaging.currentUser?.internalId
			else {
				self.finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
				return
		}
		
		let request = MMPostUserDataRequest(internalUserId: internalId, externalUserId: MobileMessaging.currentUser?.externalId)
		
		remoteAPIQueue.perform(request: request) { result in
			self.handleResult(result)
			self.finishWithError(result.error)
		}
	}
	
	private func sendUserData() {
		guard let user = MobileMessaging.currentUser, let internalId = user.internalId
			else {
				self.finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
				return
		}
		
		let request = MMPostUserDataRequest(internalUserId: internalId, externalUserId: user.externalId, predefinedUserData: user.predefinedData, customUserData: user.customData)
		
		remoteAPIQueue.perform(request: request) { result in
			self.handleResult(result)
			self.finishWithError(result.error ?? result.value?.error?.foundationError)
		}
	}
	
	private func handleResult(_ result: MMUserDataSyncResult) {
		self.context.performAndWait {
			switch result {
			case .Success(let response):
				guard let installationObject = self.installationObject else {
					return
				}
				
				installationObject.customUserData = response.customData
				installationObject.predefinedUserData = response.predefinedData
				
				installationObject.resetDirtyAttribute(attributes: SyncableAttributesSet.userData) // all user data now in sync
				self.context.MM_saveToPersistentStoreAndWait()
				MMLogDebug("User data: successfully synced")
				
				NotificationCenter.mm_postNotificationFromMainThread(name: MMNotificationUserDataSynced, userInfo: nil)
				
			case .Failure(let error):
				MMLogError("User data: sync request failed with error: \(error)")
				return
			case .Cancel:
				MMLogError("User data: sync request cancelled.")
				return
			}
		}
	}
	
	override func finished(_ errors: [NSError]) {
		self.finishBlock?(errors.first)
	}
}
