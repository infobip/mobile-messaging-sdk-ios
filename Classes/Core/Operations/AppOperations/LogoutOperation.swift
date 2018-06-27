//
//  LogoutOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 03/04/2018.
//

import Foundation
import CoreData

class LogoutOperation: Operation {
	let mmContext: MobileMessaging
	let finishBlock: ((NSError?) -> Void)?
	
	init(mmContext: MobileMessaging, finishBlock: ((NSError?) -> Void)? = nil) {
		self.finishBlock = finishBlock
		self.mmContext = mmContext
		super.init()
	}
	
	override func execute() {
		MMLogDebug("[Logout] starting synchronization...")
		self.sendRequest()
	}
	
	private func sendRequest() {
		guard mmContext.currentUser.pushRegistrationId != nil else {
			MMLogDebug("[Logout] No registration. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
			return
		}
		
		MMLogDebug("[Logout] performing request...")
		mmContext.remoteApiProvider.logout() { result in
			self.handleResultAndFinish(result)
		}
	}
	
	private func handleResultAndFinish(_ result: LogoutResult) {
		switch result {
		case .Success:
			MMLogDebug("[Logout] request secceeded")
			
			let loopGroup = DispatchGroup()
			var logoutError: NSError?
			
			MMLogDebug("[Logout] logging out subservices...")
			mmContext.subservices.values.forEach { subservice in
				loopGroup.enter()
				subservice.logout(mmContext, completion: { error in
					logoutError = logoutError == nil ? error : logoutError
					loopGroup.leave()
				})
			}
			
			loopGroup.notify(queue: DispatchQueue.global(qos: .default), execute: {
				self.finishWithError(logoutError)
			})
		case .Failure(let error):
			MMLogError("[Logout] request failed with error: \(error.orNil)")
			self.finishWithError(result.error)
		case .Cancel:
			MMLogError("[Logout] request cancelled.")
			self.finish()
		}
	}
	
	override func finished(_ errors: [NSError]) {
		MMLogDebug("[Logout] finished with errors: \(errors)")
		finishBlock?(errors.first)
	}
}
