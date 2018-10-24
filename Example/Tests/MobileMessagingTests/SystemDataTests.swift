//
//  SystemDataTests.swift
//  MobileMessagingExample
//
//  Created by Andrey K. on 29/08/16.
//

import XCTest
@testable import MobileMessaging

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
		
		mobileMessagingInstance.remoteApiProvider.registrationQueue = MMRemoteAPIMock(performRequestCompanionBlock: nil, completionCompanionBlock: nil, responseSubstitution: responseStubBlock)
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
		mobileMessagingInstance.remoteApiProvider.registrationQueue = MMRemoteAPIMock(performRequestCompanionBlock: requestCompanionBlock, completionCompanionBlock: nil, responseSubstitution: responseStubBlock)
		
		//requirements
		self.mobileMessagingInstance.currentInstallation.deviceToken = "stub"
		self.mobileMessagingInstance.currentUser.pushRegistrationId = "stub"
		
		GeofencingService.sharedInstance = GeofencingServiceDisabledStub(mmContext: mobileMessagingInstance)
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
	
	func testThatSystemDataNotSentWhenDisabled() {
		weak var expectationD = self.expectation(description: "system data sync completed disabled")
		weak var expectationE = self.expectation(description: "system data sync completed enabled")

		
		MobileMessaging.privacySettings.systemInfoSendingDisabled = true
		
		let requestCompanionBlockDisabled: (Any) -> Void = { request in
			if let request = request as? SystemDataSyncRequest {
				XCTAssertNil(request.body?[Consts.SystemDataKeys.appVer])
				XCTAssertNil(request.body?[Consts.SystemDataKeys.deviceManufacturer])
				XCTAssertNil(request.body?[Consts.SystemDataKeys.deviceModel])
				XCTAssertNil(request.body?[Consts.SystemDataKeys.osVer])
				XCTAssertNotNil(request.body?[Consts.SystemDataKeys.sdkVersion])
				XCTAssertNotNil(request.body?[Consts.SystemDataKeys.geofencingServiceEnabled])
				XCTAssertNotNil(request.body?[Consts.SystemDataKeys.notificationsEnabled])
                XCTAssertNil(request.body?[Consts.SystemDataKeys.deviceSecure])
			}
		}
		
		let requestCompanionBlockEnabled: (Any) -> Void = { request in
			if let request = request as? SystemDataSyncRequest {
				XCTAssertNotNil(request.body?[Consts.SystemDataKeys.appVer])
				XCTAssertNotNil(request.body?[Consts.SystemDataKeys.deviceManufacturer])
				XCTAssertNotNil(request.body?[Consts.SystemDataKeys.deviceModel])
				XCTAssertNotNil(request.body?[Consts.SystemDataKeys.osVer])
				XCTAssertNotNil(request.body?[Consts.SystemDataKeys.sdkVersion])
				XCTAssertNotNil(request.body?[Consts.SystemDataKeys.geofencingServiceEnabled])
				XCTAssertNotNil(request.body?[Consts.SystemDataKeys.notificationsEnabled])
                XCTAssertNotNil(request.body?[Consts.SystemDataKeys.deviceSecure])
			}
		}
		
		self.mobileMessagingInstance.remoteApiProvider.registrationQueue = MMRemoteAPIMock(
		                                                                             performRequestCompanionBlock: requestCompanionBlockDisabled,
		                                                                             completionCompanionBlock: nil,
		                                                                             responseSubstitution: nil)
		self.mobileMessagingInstance.currentInstallation.syncSystemDataWithServer { (error) in
			expectationD?.fulfill()
		}
		
		MobileMessaging.privacySettings.systemInfoSendingDisabled = false
		self.mobileMessagingInstance.remoteApiProvider.registrationQueue = MMRemoteAPIMock(
		                                                                                  performRequestCompanionBlock: requestCompanionBlockEnabled,
		                                                                                  completionCompanionBlock: nil,
		                                                                                  responseSubstitution: nil)
		self.mobileMessagingInstance.currentInstallation.syncSystemDataWithServer { (error) in
			expectationE?.fulfill()
		}
		
		self.waitForExpectations(timeout: 60, handler: nil)
	}
}
