//
//  SetEmailOperation.swift
//  Pods
//
//  Created by Andrey K. on 18/04/16.
//
//

import UIKit
import CoreData

final class SetEmailOperation: Operation {
	var context: NSManagedObjectContext
	var finishBlock: ((NSError?) -> Void)?
	var remoteAPIQueue: MMRemoteAPIQueue
	var email: String
	
	init(email: String, context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, finishBlock: ((NSError?) -> Void)?) {
		self.email = email
		self.context = context
		self.remoteAPIQueue = remoteAPIQueue
		self.finishBlock = finishBlock
		
		super.init()
		
		self.addCondition(RegistrationCondition())
	}
	
	override func execute() {
		context.performBlockAndWait {
			guard let installation = InstallationManagedObject.MR_findFirstInContext(self.context) else {
				self.finish()
				return
			}
			guard let internalId = installation.internalId else {
				self.finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
				return
			}
			
			let request = MMPostEmailRequest(internalId: internalId, email: self.email)
			self.remoteAPIQueue.performRequest(request) { result in
				if result.error == nil {
					self.context.performBlockAndWait {
						installation.email = self.email
						self.context.MR_saveToPersistentStoreAndWait()
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
