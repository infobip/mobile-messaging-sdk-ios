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

		mobileMessagingInstance.currentInstallation.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		let remoteProviderMock = RemoteApiInstanceAttributesMock()
		remoteProviderMock.patchInstanceClosure = { applicationCode, pushRegistrationId, installation, attributesSet, completion in
			completion(UpdateInstanceDataResult.Success(EmptyResponse()))
		}
		mobileMessagingInstance.remoteApiProvider = remoteProviderMock
		GeofencingService.sharedInstance = GeofencingServiceDisabledStub(mmContext: mobileMessagingInstance)
		GeofencingService.sharedInstance!.start({ _ in })
		
		let geoDisabledSystemDataHash = MobileMessaging.currentInstallation!.systemDataHash
		var geoEnabledSystemDataHash: Int64!
		
		GeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: mobileMessagingInstance)
		GeofencingService.sharedInstance!.start({ _ in })
		
		MobileMessaging.currentInstallation?.syncSystemDataWithServer(completion: { (error) in
			DispatchQueue.main.async {
				geoEnabledSystemDataHash = MobileMessaging.currentInstallation!.systemDataHash
				
				GeofencingService.sharedInstance = GeofencingServiceDisabledStub(mmContext: self.mobileMessagingInstance)
				GeofencingService.sharedInstance!.start({ _ in })
				
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
		let remoteProviderMock = RemoteApiInstanceAttributesMock()
		remoteProviderMock.patchInstanceClosure = { applicationCode, pushRegistrationId, installation, attributesSet, completion in
			sentSettings.append(MobileMessaging.userAgent.notificationsEnabled)
			completion(UpdateInstanceDataResult.Success(EmptyResponse()))
		}
		mobileMessagingInstance.remoteApiProvider = remoteProviderMock

		//requirements
		mobileMessagingInstance.currentInstallation.deviceToken = "stub"
		mobileMessagingInstance.currentInstallation.pushRegistrationId = "stub"
		mobileMessagingInstance.currentInstallation.systemDataHash = 0
		mobileMessagingInstance.currentInstallation.persist()

		GeofencingService.sharedInstance = GeofencingServiceDisabledStub(mmContext: mobileMessagingInstance)
		MobileMessaging.application = NotificationsEnabledMock()

		// system data sends notificationsEnabled: true (initial) +1
		self.mobileMessagingInstance.currentInstallation.syncSystemDataWithServer(completion: { error in
			
			MobileMessaging.application = NotificationsDisabledMock()
			// system data sends notificationsEnabled: false  (notification settings changed) +1
			self.mobileMessagingInstance.currentInstallation.syncSystemDataWithServer(completion: { error in

				// system data request sending not expected (notification settings the same)
				self.mobileMessagingInstance.currentInstallation.syncSystemDataWithServer(completion: { error in
					expectation?.fulfill()
				})
			})
		})

		self.waitForExpectations(timeout: 6000) { error in
			XCTAssertEqual(sentSettings.count, 2)
			XCTAssertTrue(sentSettings.contains(true))
			XCTAssertTrue(sentSettings.contains(false))
		}
	}

	func testThatSystemDataRespectsPrivacySettings() {
		do {
			MobileMessaging.privacySettings.systemInfoSendingDisabled = true
			let body = MobileMessaging.userAgent.systemData.requestPayload
			XCTAssertNil(body[Consts.SystemDataKeys.appVer])
			XCTAssertNil(body[Consts.SystemDataKeys.deviceManufacturer])
			XCTAssertNil(body[Consts.SystemDataKeys.deviceModel])
			XCTAssertNil(body[Consts.SystemDataKeys.osVer])
			XCTAssertNil(body[Consts.SystemDataKeys.language])
			XCTAssertNotNil(body[Consts.SystemDataKeys.sdkVersion])
			XCTAssertNotNil(body[Consts.SystemDataKeys.geofencingServiceEnabled])
			XCTAssertNotNil(body[Consts.SystemDataKeys.notificationsEnabled])
			XCTAssertNil(body[Consts.SystemDataKeys.deviceSecure])
		}

		do {
			MobileMessaging.privacySettings.systemInfoSendingDisabled = false
			let body = MobileMessaging.userAgent.systemData.requestPayload
			XCTAssertNotNil(body[Consts.SystemDataKeys.appVer])
			XCTAssertNotNil(body[Consts.SystemDataKeys.deviceManufacturer])
			XCTAssertNotNil(body[Consts.SystemDataKeys.deviceModel])
			XCTAssertNotNil(body[Consts.SystemDataKeys.osVer])
			XCTAssertNotNil(body[Consts.SystemDataKeys.language])
			XCTAssertNotNil(body[Consts.SystemDataKeys.sdkVersion])
			XCTAssertNotNil(body[Consts.SystemDataKeys.geofencingServiceEnabled])
			XCTAssertNotNil(body[Consts.SystemDataKeys.notificationsEnabled])
			XCTAssertNotNil(body[Consts.SystemDataKeys.deviceSecure])
		}
	}
}
