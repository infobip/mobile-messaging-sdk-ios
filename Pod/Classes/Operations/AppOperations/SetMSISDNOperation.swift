//
//  SetMSISDNOperation.swift
//  Pods
//
//  Created by Andrey K. on 18/04/16.
//
//

import UIKit
import CoreData

final class SetMSISDNOperation: Operation {
	var context: NSManagedObjectContext
	var finishBlock: ((NSError?) -> Void)?
	var remoteAPIQueue: MMRemoteAPIQueue
	var msisdn: String
	
	init(msisdn: String, context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, finishBlock: ((NSError?) -> Void)?) {
		self.msisdn = msisdn
		self.context = context
		self.remoteAPIQueue = remoteAPIQueue
		self.finishBlock = finishBlock
		
		super.init()
		
		self.addCondition(RegistrationCondition())
	}
	
	override func execute() {
		context.performBlockAndWait {
			guard self.msisdn.characters.count > 0 else {
				self.finishWithError(NSError(type: MMInternalErrorType.EmptyMsisdn))
				return
			}
			
			guard let installation = InstallationManagedObject.MM_findFirstInContext(self.context) else {
				self.finish()
				return
			}
			guard let internalId = installation.internalId else {
				self.finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
				return
			}
			
			let request = MMPostMSISDNRequest(internalId: internalId, msisdn: self.msisdn)
			self.remoteAPIQueue.performRequest(request) { result in
				if result.error == nil {
					self.context.performBlockAndWait {
						installation.msisdn = self.msisdn
						self.context.MM_saveToPersistentStoreAndWait()
					}
				}
				self.finishWithError(result.error)
			}
		}
	}
	
	override func finished(errors: [NSError]) {
		finishBlock?(errors.first)
	}
}
