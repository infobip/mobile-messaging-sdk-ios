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
	var installationObject: InstallationManagedObject!
	let finishBlock: (NSError? -> Void)?
	let remoteAPIQueue: MMRemoteAPIQueue
	let user: MMUser
	var dirtyAttributes = SyncableAttributesSet(rawValue: 0)
	let forceSync : Bool
	
	init(user: MMUser, context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, finishBlock: (NSError? -> Void)? = nil, force: Bool = false) {
		self.context = context
		self.remoteAPIQueue = remoteAPIQueue
		self.finishBlock = finishBlock
		self.user = user
		self.forceSync = force
		
		super.init()
		
		self.addCondition(RegistrationCondition())
	}
	
	private var installationHasChanges: Bool {
		return installationObject.changedValues().isEmpty == false
	}
	
	override func execute() {
		context.performBlockAndWait {
			guard let installation = InstallationManagedObject.MM_findFirstInContext(context: self.context) else {
				self.finish()
				return
			}
			
			self.installationObject = installation
			self.dirtyAttributes = installation.dirtyAttributesSet
			
			if (self.installationHasChanges) {
				MMLogDebug("Saving installation locally...")
				self.context.MM_saveToPersistentStoreAndWait()
			} else {
				MMLogDebug("Installation object has no changes. No need to save installation locally.")
			}
			
			self.sendUserDataIfNeeded()
		}
	}
	
	private var userDataChanged: Bool {
		return installationObject.dirtyAttributesSet.intersect(SyncableAttributesSet.userData).isEmpty == false
	}
	
	private var shouldSendRequest: Bool {
		return userDataChanged
	}
	
	private func sendUserDataIfNeeded() {
		if shouldSendRequest || forceSync {
			MMLogDebug("Sending user data updates to the server...")
			self.sendUserData()
		} else {
			MMLogDebug("User data has no changes, no need to send to the server.")
			finish()
		}
	}
	
	private func sendUserData() {
		guard let internalId = user.internalId else {
			self.finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
			return
		}
		
		let request = MMPostUserDataRequest(internalUserId: internalId, externalUserId: user.externalId, predefinedUserData: user.predefinedData ?? [String: AnyObject](), customUserData: user.customData ?? [String: AnyObject]())
		
		remoteAPIQueue.performRequest(request) { result in
			self.handleResult(result)
			self.finishWithError(result.error)
		}
	}
	
	private func handleResult(result: MMUserDataFetchResult) {
		self.context.performBlockAndWait {
			switch result {
			case .Success(let response):
				guard let installationObject = self.installationObject else {
					return
				}

				installationObject.customUserData = response.customData
				installationObject.predefinedUserData = response.predefinedData
				
				installationObject.resetDirtyAttribute(SyncableAttributesSet.userData) // all user data now in sync
				self.context.MM_saveToPersistentStoreAndWait()
				MMLogDebug("User data successfully synced")
				
				NSNotificationCenter.mm_postNotificationFromMainThread(MMNotificationUserDataSynced, userInfo: nil)
				
			case .Failure(let error):
				MMLogError("User data sync request failed with error: \(error)")
				return
			case .Cancel:
				MMLogError("User data sync request cancelled.")
				return
			}
		}
	}
	
	override func finished(errors: [NSError]) {
		finishBlock?(errors.first)
	}
}