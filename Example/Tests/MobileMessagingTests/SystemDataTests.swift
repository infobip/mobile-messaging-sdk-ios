//
//  SystemDataTests.swift
//  MobileMessagingExample
//
//  Created by Andrey K. on 29/08/16.
//

import XCTest
@testable import MobileMessaging

class UserAgentStub: UserAgent {
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

class SystemDataTests: MMTestCase {

    func testSystemDataUpdates() {
		weak var requestsCompleted = expectation(description: "requestsCompleted")

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
		
		mobileMessagingInstance.remoteApiManager.registrationQueue = MMRemoteAPIMock(baseURLString: MMTestConstants.kTestBaseURLString, appCode: MMTestConstants.kTestWrongApplicationCode, mmContext: self.mobileMessagingInstance, performRequestCompanionBlock: nil, completionCompanionBlock: nil, responseSubstitution: responseStubBlock)
		mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		
		GeofencingService.sharedInstance = GeofencingServiceDisabledStub(mmContext: mobileMessagingInstance)
		GeofencingService.sharedInstance!.start()
		
		let geoDisabledSystemDataHash = MobileMessaging.currentInstallation!.systemDataHash
		var geoEnabledSystemDataHash: Int64!
		
		GeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: mobileMessagingInstance)
		GeofencingService.sharedInstance!.start()
		
		MobileMessaging.currentInstallation?.syncSystemDataWithServer(completion: { (error) in
			DispatchQueue.main.async {
				geoEnabledSystemDataHash = MobileMessaging.currentInstallation!.systemDataHash
				
				GeofencingService.sharedInstance = GeofencingServiceDisabledStub(mmContext: self.mobileMessagingInstance)
				GeofencingService.sharedInstance!.start()
				
				MobileMessaging.currentInstallation?.syncSystemDataWithServer(completion: { (error) in
					requestsCompleted?.fulfill()
				})
			}
		})
		
		self.waitForExpectations(timeout: 60) { _ in
			XCTAssertEqual(geoDisabledSystemDataHash, 0)
			XCTAssertNotEqual(geoDisabledSystemDataHash, geoEnabledSystemDataHash)
			XCTAssertNotEqual(MobileMessaging.currentInstallation!.systemDataHash, geoDisabledSystemDataHash)
			XCTAssertNotEqual(MobileMessaging.currentInstallation!.systemDataHash, geoEnabledSystemDataHash)
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
		mobileMessagingInstance.remoteApiManager.registrationQueue = MMRemoteAPIMock(baseURLString: MMTestConstants.kTestBaseURLString, appCode: MMTestConstants.kTestWrongApplicationCode, mmContext: self.mobileMessagingInstance, performRequestCompanionBlock: requestCompanionBlock, completionCompanionBlock: nil, responseSubstitution: responseStubBlock)
		
		//requirements
		self.mobileMessagingInstance.currentInstallation.deviceToken = "stub"
		self.mobileMessagingInstance.currentUser.pushRegistrationId = "stub"
		
		GeofencingService.sharedInstance = GeofencingServiceDisabledStub(mmContext: mobileMessagingInstance)
		self.mobileMessagingInstance.application = NotificationsEnabledMock()
		
		// system data request sending is expected (initial) +1
		self.mobileMessagingInstance.currentInstallation.syncSystemDataWithServer(completion: { error in
			
			self.mobileMessagingInstance.application = NotificationsDisabledMock()
			// system data request sending is expected (notification settings changed) +1
			self.mobileMessagingInstance.currentInstallation.syncSystemDataWithServer(completion: { error in

				
				self.mobileMessagingInstance.application = NotificationsDisabledMock()
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
	
	func testThatSystemDataNotSentWhenDisabled() {
		weak var expectationD = self.expectation(description: "system data sync completed disabled")
		weak var expectationE = self.expectation(description: "system data sync completed enabled")

		
		MobileMessaging.privacySettings.systemInfoSendingDisabled = true
		
		let requestCompanionBlockDisabled: (Any) -> Void = { request in
			if let request = request as? SystemDataSyncRequest {
				XCTAssertNil(request.body?[SystemDataKeys.appVer])
				XCTAssertNil(request.body?[SystemDataKeys.deviceManufacturer])
				XCTAssertNil(request.body?[SystemDataKeys.deviceModel])
				XCTAssertNil(request.body?[SystemDataKeys.osVer])
				XCTAssertNotNil(request.body?[SystemDataKeys.sdkVersion])
				XCTAssertNotNil(request.body?[SystemDataKeys.geofencingServiceEnabled])
				XCTAssertNotNil(request.body?[SystemDataKeys.notificationsEnabled])
                XCTAssertNil(request.body?[SystemDataKeys.deviceSecure])
			}
		}
		
		let requestCompanionBlockEnabled: (Any) -> Void = { request in
			if let request = request as? SystemDataSyncRequest {
				XCTAssertNotNil(request.body?[SystemDataKeys.appVer])
				XCTAssertNotNil(request.body?[SystemDataKeys.deviceManufacturer])
				XCTAssertNotNil(request.body?[SystemDataKeys.deviceModel])
				XCTAssertNotNil(request.body?[SystemDataKeys.osVer])
				XCTAssertNotNil(request.body?[SystemDataKeys.sdkVersion])
				XCTAssertNotNil(request.body?[SystemDataKeys.geofencingServiceEnabled])
				XCTAssertNotNil(request.body?[SystemDataKeys.notificationsEnabled])
                XCTAssertNotNil(request.body?[SystemDataKeys.deviceSecure])
			}
		}
		
		self.mobileMessagingInstance.remoteApiManager.registrationQueue = MMRemoteAPIMock(baseURLString: MMTestConstants.kTestBaseURLString,
		                                                                             appCode: MMTestConstants.kTestCorrectApplicationCode,
		                                                                             mmContext: self.mobileMessagingInstance,
		                                                                             performRequestCompanionBlock: requestCompanionBlockDisabled,
		                                                                             completionCompanionBlock: nil,
		                                                                             responseSubstitution: nil)
		self.mobileMessagingInstance.currentInstallation.syncSystemDataWithServer { (error) in
			expectationD?.fulfill()
		}
		
		MobileMessaging.privacySettings.systemInfoSendingDisabled = false
		self.mobileMessagingInstance.remoteApiManager.registrationQueue = MMRemoteAPIMock(baseURLString: MMTestConstants.kTestBaseURLString,
		                                                                                  appCode: MMTestConstants.kTestCorrectApplicationCode,
		                                                                                  mmContext: self.mobileMessagingInstance,
		                                                                                  performRequestCompanionBlock: requestCompanionBlockEnabled,
		                                                                                  completionCompanionBlock: nil,
		                                                                                  responseSubstitution: nil)
		self.mobileMessagingInstance.currentInstallation.syncSystemDataWithServer { (error) in
			expectationE?.fulfill()
		}
		
		self.waitForExpectations(timeout: 60, handler: nil)
	}
}
