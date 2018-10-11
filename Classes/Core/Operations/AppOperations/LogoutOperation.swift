//
//  LogoutOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 03/04/2018.
//

import Foundation
import CoreData

struct LogoutConsts {
	static var failuresNumberLimit = 3
}

@objc public enum LogoutStatus: Int {
	case undefined = 0, pending
}

class LogoutOperation: Operation {
	let mmContext: MobileMessaging
	let finishBlock: ((LogoutStatus, NSError?) -> Void)?
	let pushRegistrationId: String?
	let applicationCode: String
	
	init(mmContext: MobileMessaging, finishBlock: ((LogoutStatus, NSError?) -> Void)? = nil) {
		self.finishBlock = finishBlock
		self.mmContext = mmContext
		self.pushRegistrationId = mmContext.currentUser?.pushRegistrationId
		self.applicationCode = mmContext.applicationCode
		super.init()
	}
	
	override func execute() {
		MMLogDebug("[Logout] starting...")
		self.sendRequest()
	}
	
	private func sendRequest() {
		guard !isCancelled else {
			finish()
			return
		}
		if let pushRegistrationId = pushRegistrationId {
			MMLogDebug("[Logout] performing request...")
			mmContext.remoteApiProvider.logout(applicationCode: self.mmContext.applicationCode, pushRegistrationId: pushRegistrationId) { result in
				self.handleResultAndFinish(result)
			}
		} else {
			finishWithError(NSError(type: .NoRegistration))
		}
	}
	
	private func handleResultAndFinish(_ result: LogoutResult) {
		switch result {
		case .Success:
			MMLogDebug("[Logout] request secceeded")

			switch mmContext.currentInstallation.currentLogoutStatus {
			case .pending:
				MMLogDebug("[Logout] current logout status: pending")
				self.mmContext.currentInstallation.currentLogoutStatus = .undefined
				self.mmContext.apnsRegistrationManager.registerForRemoteNotifications()
                NotificationCenter.mm_postNotificationFromMainThread(name: MMNotificationLogoutCompleted, userInfo: nil)
				self.finish()
			case .undefined:
				MMLogDebug("[Logout] current logout status: undefined")
				logoutSubservices { (error) in
					self.finishWithError(error)
				}
			}
		case .Failure(let error):
			MMLogError("[Logout] request failed with error: \(error.orNil)")
            mmContext.currentInstallation.logoutFailCounter = mmContext.currentInstallation.logoutFailCounter + 1

            switch mmContext.currentInstallation.currentLogoutStatus {
            case .pending:
                MMLogDebug("[Logout] current logout status: pending")

                if mmContext.currentInstallation.logoutFailCounter >= LogoutConsts.failuresNumberLimit {
                    self.mmContext.currentInstallation.currentLogoutStatus = .undefined
                    self.mmContext.apnsRegistrationManager.registerForRemoteNotifications()
                }

                self.finishWithError(error)
            case .undefined:
                MMLogDebug("[Logout] current logout status: undefined")
                logoutSubservices { _ in
                    self.mmContext.currentInstallation.currentLogoutStatus = .pending
                    self.mmContext.apnsRegistrationManager.unregister()

                    self.finishWithError(error)
                }
            }
		case .Cancel:
			MMLogError("[Logout] request cancelled.")
			self.finish()
		}
	}

	private func logoutSubservices(completion: @escaping (NSError?) -> Void) {
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
			completion(logoutError)
		})
	}
	
	override func finished(_ errors: [NSError]) {
		MMLogDebug("[Logout] finished with errors: \(errors)")
		finishBlock?(mmContext.currentInstallation.currentLogoutStatus, errors.first)
	}
}
