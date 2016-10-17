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
	let finishBlock: (NSError? -> Void)?
	let remoteAPIQueue: MMRemoteAPIQueue
	
	private var installationObject: InstallationManagedObject!
	private var dirtyAttributes = SyncableAttributesSet(rawValue: 0)
	private let onlyFetching: Bool //TODO: remove for v2 User Data API.
	
	convenience init(fetchingOperationWithContext context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, finishBlock: (NSError? -> Void)? = nil) {
		self.init(context: context, remoteAPIQueue: remoteAPIQueue, onlyFetching: true, finishBlock: finishBlock)
	}
	
	convenience init(syncOperationWithContext context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, finishBlock: (NSError? -> Void)? = nil) {
		self.init(context: context, remoteAPIQueue: remoteAPIQueue, onlyFetching: false, finishBlock: finishBlock)
	}
	
	private init(context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, onlyFetching: Bool, finishBlock: (NSError? -> Void)? = nil) {
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
		context.performBlockAndWait {
			guard let installation = InstallationManagedObject.MM_findFirstInContext(context: self.context) else {
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
		return installationObject.dirtyAttributesSet.intersect(SyncableAttributesSet.userData).isEmpty == false
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
	
	private func handleResult(result: MMUserDataSyncResult) {
		self.context.performBlockAndWait {
			switch result {
			case .Success(let response):
				guard let installationObject = self.installationObject else {
					return
				}

				installationObject.customUserData = response.customData?.reduce(nil, combine: { (result, element) -> [String: AnyObject]? in
					return result + element.mapToFoundationTypesDict()
				}) ?? nil
				installationObject.predefinedUserData = response.predefinedData
				
				installationObject.resetDirtyAttribute(SyncableAttributesSet.userData) // all user data now in sync
				self.context.MM_saveToPersistentStoreAndWait()
				MMLogDebug("User data: successfully synced")
				
				NSNotificationCenter.mm_postNotificationFromMainThread(MMNotificationUserDataSynced, userInfo: nil)
				
			case .Failure(let error):
				MMLogError("User data: sync request failed with error: \(error)")
				return
			case .Cancel:
				MMLogError("User data: sync request cancelled.")
				return
			}
		}
	}
	
	override func finished(errors: [NSError]) {
		self.finishBlock?(errors.first)
	}
}

struct CustomUserDataElement: DictionaryRepresentable {
	let dataKey: String
	let dataValue: CustomUserDataValue?
	
	init(dataKey: String, dataValue: UserDataSupportedTypes) {
		self.dataKey = dataKey
		if dataValue is NSNull {
			self.dataValue = nil
		} else {
			self.dataValue = CustomUserDataValue.make(withValue: dataValue)
		}
	}
	
	init?(dictRepresentation dict: [String: AnyObject]) {
		guard let k = dict.first?.0 else {
			return nil
		}
		self.dataKey = k
		if let valueDict = dict.first?.1 as? [String: AnyObject], let dataValue = valueDict["value"] as? UserDataSupportedTypes, let dataTypeString = valueDict["type"] as? String, let dataType = ContactsTypes(rawValue: dataTypeString) {
			self.dataValue = CustomUserDataValue(dataType: dataType, dataValue: dataValue)
		} else {
			self.dataValue = nil
		}
	}
	
	var dictionaryRepresentation: [String: AnyObject] {
		if let dataValue = dataValue {
			return [dataKey: ["type": dataValue.dataType.rawValue, "value": dataValue.dataValue]]
		} else {
			return [dataKey: NSNull()]
		}
	}
	
	func mapToFoundationTypesDict() -> [String: AnyObject]? {
		var result: [String: AnyObject]?
		if let value = self.dataValue {
			var dict = [String: AnyObject]()
			switch (value.dataType, value.dataValue) {
			case (ContactsTypes.string, let foundationValue as NSString):
				dict[dataKey] = foundationValue
			case (ContactsTypes.number, let foundationValue as NSNumber):
				dict[dataKey] = foundationValue
			case (ContactsTypes.date, let foundationValue as NSString):
				dict[dataKey] = NSDateStaticFormatters.ISO8601SecondsFormatter.dateFromString(foundationValue as String)
			default:
				break
			}
			result = dict
		}
		return result
	}
	
	enum ContactsTypes: String {
		case string = "String"
		case number = "Number"
		case date = "Date"
	}
	
	struct CustomUserDataValue {
		let dataType: ContactsTypes
		let dataValue: UserDataSupportedTypes
		
		static func make(withValue value: UserDataSupportedTypes) -> CustomUserDataValue? {
			switch value {
			case let v as NSString:
				return CustomUserDataValue(dataType: ContactsTypes.string, dataValue: v) //TODO: move to enums
			case let v as NSNumber:
				return CustomUserDataValue(dataType: ContactsTypes.number, dataValue: v)
			case let v as NSDate:
				return CustomUserDataValue(dataType: ContactsTypes.date, dataValue: NSDateStaticFormatters.ISO8601SecondsFormatter.stringFromDate(v))
			default:
				return nil
			}
		}
	}
}