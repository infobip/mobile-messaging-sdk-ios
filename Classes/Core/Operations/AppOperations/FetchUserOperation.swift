//
//  FetchUserAttributesOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 07/11/2018.
//

import Foundation

class FetchUserOperation: Operation {
	let mmContext: MobileMessaging
	let user: UserDataService
	let finishBlock: ((FetchUserDataResult) -> Void)?
	var result: FetchUserDataResult = .Cancel
	let attributesSet: AttributesSet

	init?(attributesSet: AttributesSet, user: UserDataService, mmContext: MobileMessaging, finishBlock: ((FetchUserDataResult) -> Void)?) {
		self.user = user
		self.mmContext = mmContext
		self.finishBlock = finishBlock

		if attributesSet.isEmpty {
			MMLogDebug("[FetchUserOperation] There are no attributes to fetch. Aborting...")
			return nil
		} else {
			self.attributesSet = attributesSet
		}
	}

	override func execute() {
		guard mmContext.currentInstallation.currentDepersonalizationStatus != .pending else {
			MMLogWarn("[FetchUserOperation] Logout pending. Canceling...")
			finishWithError(NSError(type: MMInternalErrorType.PendingLogout))
			return
		}
		guard !isCancelled else {
			MMLogDebug("[FetchUserOperation] cancelled...")
			finish()
			return
		}
		MMLogDebug("[FetchUserOperation] Started...")

		fetchUserDataIfNeeded()
	}

	private func fetchUserDataIfNeeded() {
		guard let pushRegistrationId = mmContext.currentInstallation.pushRegistrationId else {
			MMLogWarn("[FetchUserOperation] There is no registration. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
			return
		}
		guard mmContext.apnsRegistrationManager.isRegistrationHealthy else {
			MMLogWarn("[FetchUserOperation] Registration is not healthy. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.InvalidRegistration))
			return
		}

		MMLogDebug("[FetchUserOperation] fetching from server...")
		fetchUserData(pushRegistrationId: pushRegistrationId)
	}

	private func fetchUserData(pushRegistrationId: String) {
		mmContext.remoteApiProvider.getUser(applicationCode: mmContext.applicationCode, pushRegistrationId: pushRegistrationId)
		{ result in
			self.handleResult(result)
			self.finishWithError(result.error)
		}
	}

	private func handleResult(_ result: FetchUserDataResult) {
		guard !isCancelled else {
			MMLogDebug("[FetchUserOperation] cancelled.")
			return
		}
		self.result = result

		switch result {
		case .Success(let response):
			if user.isChanged {
				return
			}
			//TODO: use apply User to UserService
			attributesSet.forEach { (att) in
				switch att {
				case .customUserAttributes:
					user.customAttributes = response.customAttributes
				case .firstName:
					user.firstName = response.firstName
				case .middleName:
					user.middleName = response.middleName
				case .lastName:
					user.lastName = response.lastName
				case .externalUserId:
					user.externalUserId = response.externalUserId
				case .birthday:
					user.birthday = response.birthday
				case .gender:
					user.gender = response.gender
				case .emails:
					user.emails = response.emails
				case .phones:
					user.phones = response.phones
				case .tags:
					user.tags = response.tags
				case .instances:
					user.installations = response.installations
				case .customInstanceAttributes,.customInstanceAttribute(key: _),.customUserAttribute(key: _),.applicationCode,.applicationUserId,.badgeNumber,.pushServiceToken,.isPrimaryDevice,.location,.depersonalizeFailCounter,.depersonalizeStatusValue,.pushRegistrationId,.registrationEnabled,.systemDataHash:
					break
				}
			}
			user.persist()
			user.resetNeedToSync(attributesSet: attributesSet)
			user.persist()
			MMLogDebug("[FetchUserOperation] successfully synced")
		case .Failure(let error):
			MMLogError("[FetchUserOperation] sync request failed with error: \(error.orNil)")
			return
		case .Cancel:
			MMLogWarn("[FetchUserOperation] sync request cancelled.")
			return
		}
	}

	override func finished(_ errors: [NSError]) {
		MMLogDebug("[FetchUserOperation] finished with errors: \(errors)")
		finishBlock?(result) //check what to do with errors/
	}
}
