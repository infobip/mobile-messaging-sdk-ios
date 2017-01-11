//
//  SystemDataTests.swift
//  MobileMessagingExample
//
//  Created by Andrey K. on 29/08/16.
//

import XCTest
@testable import MobileMessaging

class UserAgentStub: MMUserAgent {
	override var libraryVersion: String {
		return "1.0.0"
	}
	override var osName: String {
		return "mobile OS"
	}
	override var osVersion: String {
		return "1.0"
	}
	override var deviceName: String {
		return "iPhone Galaxy"
	}
	override var hostingAppName: String {
		return "WheatherApp"
	}
	override var hostingAppVersion: String {
		return "1.0"
	}
	override var deviceManufacturer: String {
		return "GoogleApple"
	}
}

class GeoAvailableUserAgentStub: UserAgentStub {
	override var isGeofencingServiceEnabled: Bool {
		return true
	}
}
class GeoNotAvailableUserAgentStub: UserAgentStub {
	override var isGeofencingServiceEnabled: Bool {
		return false
	}
}


class SystemDataTests: MMTestCase {

    func testSystemDataUpdates() {
		weak var requestsCompleted = expectation(description: "requestsCompleted")
		let ctx = self.storage.mainThreadManagedObjectContext!
		
	
		let responseStubBlock: (Any) -> JSON? = { request -> JSON? in
			if request is RegistrationRequest {
				return JSON(["pushRegistrationEnabled": true,
				             "deviceApplicationInstanceId": "stub",
				             "registrationId": "stub",
				             "platformType": "APNS"])
			}
			
			if let request = request as? SystemDataSyncRequest {
				return JSON(request.systemData.dictionaryRepresentation)
			}
			return nil
		}
		
		mobileMessagingInstance.remoteApiManager.registrationQueue = MMRemoteAPIMock(baseURLString: MMTestConstants.kTestBaseURLString, appCode: MMTestConstants.kTestWrongApplicationCode, performRequestCompanionBlock: nil, completionCompanionBlock: nil, responseSubstitution: responseStubBlock)
		
		mobileMessagingInstance.currentUser.internalId = MMTestConstants.kTestCorrectInternalID
		
		var initialSystemDataHash: Int64!
		MobileMessaging.userAgent = GeoNotAvailableUserAgentStub()
		
		if let installation = InstallationManagedObject.MM_findFirstInContext(ctx) {
			initialSystemDataHash = installation.systemDataHash
		}
		
		var updatedSystemDataHash: Int64!
		MobileMessaging.userAgent = GeoAvailableUserAgentStub()
		MobileMessaging.currentInstallation?.syncSystemDataWithServer(completion: { (error) in
			ctx.reset()
			if let installation = InstallationManagedObject.MM_findFirstInContext(ctx) {
				updatedSystemDataHash = installation.systemDataHash
			}
			
			MobileMessaging.userAgent = GeoNotAvailableUserAgentStub()
			MobileMessaging.currentInstallation?.syncSystemDataWithServer(completion: { (error) in
				requestsCompleted?.fulfill()
			})
		})
		
		self.waitForExpectations(timeout: 60) { _ in
			ctx.reset()
			if let installation = InstallationManagedObject.MM_findFirstInContext(ctx) {
				XCTAssertEqual(initialSystemDataHash, 0)
				XCTAssertNotEqual(initialSystemDataHash, updatedSystemDataHash)
				XCTAssertNotEqual(installation.systemDataHash, initialSystemDataHash)
				XCTAssertNotEqual(installation.systemDataHash, updatedSystemDataHash)
			}
		}
    }
	
	func testThatNotificationsSettingsIsBeingSyncedAfterChanged() {
		//Preparations
		weak var expectation = self.expectation(description: "registration sent")
		var sentSettings = [Bool]()
		
		let requestCompanionBlock: (Any) -> Void = { request in
			if let request = request as? SystemDataSyncRequest {
				DispatchQueue.main.async {
					sentSettings.append(request.systemData.notificationsEnabled)
				}
			}
		}
		let responseStubBlock: (Any) -> JSON? = { request -> JSON? in
			if let request = request as? SystemDataSyncRequest {
				return JSON(request.systemData.dictionaryRepresentation)
			}
			return nil
		}
		mobileMessagingInstance.remoteApiManager.registrationQueue = MMRemoteAPIMock(baseURLString: MMTestConstants.kTestBaseURLString, appCode: MMTestConstants.kTestWrongApplicationCode, performRequestCompanionBlock: requestCompanionBlock, completionCompanionBlock: nil, responseSubstitution: responseStubBlock)
		
		//requirements
		self.mobileMessagingInstance.currentInstallation.deviceToken = "stub"
		self.mobileMessagingInstance.currentUser.internalId = "stub"
		
		MobileMessaging.userAgent = GeoNotAvailableUserAgentStub()
		MobileMessaging.application = NotificationsEnabledMock()
		
		// system data request sending is expected (initial) +1
		self.mobileMessagingInstance.currentInstallation.syncSystemDataWithServer(completion: { error in
			
			MobileMessaging.application = NotificationsDisabledMock()
			// system data request sending is expected (notification settings changed) +1
			self.mobileMessagingInstance.currentInstallation.syncSystemDataWithServer(completion: { error in

				
				MobileMessaging.application = NotificationsDisabledMock()
				// system data request sending not expected (notification settings the same)
				self.mobileMessagingInstance.currentInstallation.syncSystemDataWithServer(completion: { error in
					expectation?.fulfill()
				})
			})
		})
		
		self.waitForExpectations(timeout: 60) { error in
			XCTAssertEqual(sentSettings.count, 2)
			XCTAssertTrue(sentSettings.contains(true))
			XCTAssertTrue(sentSettings.contains(false))
		}
	}
}
