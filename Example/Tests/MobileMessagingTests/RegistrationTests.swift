//
//  RegistrationTests.swift
//  RegistrationTests
//
//  Created by Andrey K. on 17/02/16.
//

import XCTest
@testable import MobileMessaging
import CoreLocation

final class RegistrationTests: MMTestCase {

	func testInstanceDataFetchingDecoding() {
		weak var expectation = self.expectation(description: "data fetched")
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID

		let responseStub: (Any) -> JSON? = { request -> JSON? in
			switch request {
			case (is GetInstance):
				let jsonStr = """
				{
					"notificationsEnabled": true,
					"pushRegId": "\(MMTestConstants.kTestCorrectInternalID)",
					"isPrimary": true,
					"regEnabled": true,
					"applicationUserId": "appUserId",
					"customAttributes": {
						"Manufacturer": "_Apple_",
						"Model": 1,
						"ReleaseDate": "1983-05-25"
					}
				}
"""
				return JSON.parse(jsonStr)
			default:
				return nil
			}
		}

		mobileMessagingInstance.remoteApiProvider.registrationQueue = MMRemoteAPIMock(
			performRequestCompanionBlock: nil,
			completionCompanionBlock: nil,
			responseStub: responseStub)

		mobileMessagingInstance.installationService.fetchFromServer(completion: { (installation, error) in
			XCTAssertNil(error)
			XCTAssertEqual(installation.pushRegistrationId, MMTestConstants.kTestCorrectInternalID)
			XCTAssertEqual(installation.isPrimaryDevice, true)
			XCTAssertEqual(installation.isPushRegistrationEnabled, true)
			XCTAssertEqual(installation.applicationUserId, "appUserId")

			XCTAssertEqual(installation.customAttributes! as NSDictionary, ["Manufacturer" : "_Apple_", "Model": NSNumber(value: 1), "ReleaseDate": darthVaderDateOfDeath])
			expectation?.fulfill()
		})

		waitForExpectations(timeout: 20, handler: nil)
	}

	func testInstanceDataFetchingMustBeIgnoredIfPushRegIdDifferent() {
		weak var expectation = self.expectation(description: "data fetched")
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID

		let responseStub: (Any) -> JSON? = { request -> JSON? in
			switch request {
			case (is GetInstance):
				let jsonStr = """
				{
				"pushRegId": "differentPushRegId",
				"applicationUserId": "appUserId"
				}
				"""
				return JSON.parse(jsonStr)
			default:
				return nil
			}
		}

		mobileMessagingInstance.remoteApiProvider.registrationQueue = MMRemoteAPIMock(
			performRequestCompanionBlock: nil,
			completionCompanionBlock: nil,
			responseStub: responseStub)

		mobileMessagingInstance.installationService.fetchFromServer(completion: { (installation, error) in
			XCTAssertNil(error)
			XCTAssertEqual(installation.pushRegistrationId, MMTestConstants.kTestCorrectInternalID)
			XCTAssertEqual(installation.applicationUserId, nil)
			expectation?.fulfill()
		})

		waitForExpectations(timeout: 20, handler: nil)
	}

	func testInstallationPersisting() {
		XCTAssertNil(self.mobileMessagingInstance.resolveInstallation().pushServiceToken)

		weak var tokensexp = expectation(description: "device tokens saved")
		let maxCount = 2

		let remoteProviderMock = RemoteApiInstanceAttributesMock()
		remoteProviderMock.postInstanceClosure = { applicationCode, body, completion in
			completion(
				FetchInstanceDataResult.Success(Installation(applicationUserId: nil, appVersion: nil, customAttributes: nil, deviceManufacturer: nil, deviceModel: nil, deviceName: nil, deviceSecure: false, deviceTimeZone: nil, geoEnabled: false, isPrimaryDevice: true, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: nil, osVersion: nil, pushRegistrationId: "new pushRegId", pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil))
			)
		}
		remoteProviderMock.patchInstanceClosure = { _, _, _, _, completion in
			completion(
				UpdateInstanceDataResult.Success(EmptyResponse())
			)
		}
		mobileMessagingInstance.remoteApiProvider = remoteProviderMock

		for counter in 0..<maxCount { DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(counter * 100)) {
			let deviceToken = "token\(counter)".data(using: String.Encoding.utf16)

				self.mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken!) { error in
					if counter == maxCount - 1 {
						tokensexp?.fulfill()
					}
				}
		}}
		
		waitForExpectations(timeout: 100, handler: { err in
			XCTAssertEqual(self.mobileMessagingInstance.resolveInstallation().pushServiceToken, "token\(maxCount-1)".mm_toHexademicalString, "Most recent token must be persisted")
			XCTAssertNil(Installation.delta["pushServiceToken"])
		})
	}

	func testRegisterForRemoteNotificationsWithDeviceToken() {
		weak var token2Saved = expectation(description: "token2 saved")

		let remoteProviderMock = RemoteApiInstanceAttributesMock()
		remoteProviderMock.postInstanceClosure = { applicationCode, body, completion in
			completion(
				FetchInstanceDataResult.Success(
					Installation(applicationUserId: nil, appVersion: nil, customAttributes: nil, deviceManufacturer: nil, deviceModel: nil, deviceName: nil, deviceSecure: false, deviceTimeZone: nil, geoEnabled: false, isPrimaryDevice: true, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: nil, osVersion: nil, pushRegistrationId: "new pushRegId", pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil)
				)
			)
		}
		remoteProviderMock.patchInstanceClosure = { _, _, _, _, completion in
			completion(
				UpdateInstanceDataResult.Success(EmptyResponse())
			)
		}
		mobileMessagingInstance.remoteApiProvider = remoteProviderMock

		mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".data(using: String.Encoding.utf16)!) {  error in
			self.mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken2".data(using: String.Encoding.utf16)!) {  error in
				token2Saved?.fulfill()
			}
		}

		self.waitForExpectations(timeout: 60) { _ in
			XCTAssertFalse(self.mobileMessagingInstance.isRegistrationStatusNeedSync)
			XCTAssertEqual(self.mobileMessagingInstance.currentInstallation().pushServiceToken, "someToken2".mm_toHexademicalString)
		}
	}
	
	func testWrongApplicationCode() {
		
		MMTestCase.cleanUpAndStop()
		MMTestCase.startWithWrongApplicationCode()

		let remoteProviderMock = RemoteApiInstanceAttributesMock()
		remoteProviderMock.postInstanceClosure = { applicationCode, body, completion in
			completion(
				FetchInstanceDataResult.Failure(
					NSError(type: .UnknownError)
				)
			)
		}
		remoteProviderMock.patchInstanceClosure = { _, _, _, _, completion in
			completion(
				UpdateInstanceDataResult.Success(EmptyResponse())
			)
		}
		mobileMessagingInstance.remoteApiProvider = remoteProviderMock
		
		weak var expectation = self.expectation(description: "Installation data updating")
		mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".data(using: String.Encoding.utf16)!) {  error in
			expectation?.fulfill()
		}
		self.waitForExpectations(timeout: 60) { _ in
			XCTAssertNotNil(Installation.delta["pushServiceToken"])
			XCTAssertNil(self.mobileMessagingInstance.resolveInstallation().pushRegistrationId)
			XCTAssertEqual(self.mobileMessagingInstance.resolveInstallation().pushServiceToken, "someToken".mm_toHexademicalString)
		}
	}

	func testTokenSendsTwice() {
		var requestSentCounter = 0
		MobileMessaging.userAgent = UserAgentStub()
		
		MobileMessaging.sharedInstance?.remoteApiProvider.registrationQueue = MMRemoteAPIMock(performRequestCompanionBlock: { request in
			switch request {
			case (is PostInstance), (is PatchInstance):
				requestSentCounter += 1
			default:
				break
			}
		})

		weak var expectation1 = expectation(description: "notification1")
		weak var expectation2 = expectation(description: "notification2")

		mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".data(using: String.Encoding.utf16)!) {  error in
			XCTAssertNil(error)
			expectation1?.fulfill()

			self.mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".data(using: String.Encoding.utf16)!) {  error in
				XCTAssertNil(error)
				expectation2?.fulfill()
			}
		}
		
		self.waitForExpectations(timeout: 60) { error in
			XCTAssertEqual(requestSentCounter, 2)
		}
	}
	
	func testRegistrationDataNotSendsWithoutToken() {
		weak var syncInstallationWithServer = expectation(description: "sync1")
		var requestSentCounter = 0
		let requestPerformCompanion: (Any) -> Void = { request in
			switch request {
			case (is PostInstance), (is PatchInstance):
				requestSentCounter += 1
			default:
				break
			}
		}
		mobileMessagingInstance.remoteApiProvider.registrationQueue = MMRemoteAPIMock(
			performRequestCompanionBlock: requestPerformCompanion,
			completionCompanionBlock: nil,
			responseStub: nil)
		
		if MobileMessaging.currentInstallation == nil {
			XCTFail("Installation is nil")
		}

		MobileMessaging.sharedInstance?.installationService.syncWithServer({ (error) -> Void in
			syncInstallationWithServer?.fulfill()
		})
		
		self.waitForExpectations(timeout: 60, handler: { err in
			XCTAssertEqual(requestSentCounter, 0)
		})
	}
	
	func testThatRegistrationEnabledStatusIsBeingSyncedAfterChanged() {
		weak var tokenSynced = self.expectation(description: "registration sent")
		weak var regDisabledStatusSynced = self.expectation(description: "registration sent")
		weak var regEnabledStatusSynced = self.expectation(description: "registration sent")
		weak var regEnabled2StatusSynced = self.expectation(description: "registration sent")
		
		var requestSentCounter = 0
		
		let requestPerformCompanion: (Any) -> Void = { request in
			switch request {
			case  (is PatchInstance):
				requestSentCounter += 1
			default:
				break
			}
		}
		
		let responseStub: (Any) -> JSON? = { request -> JSON? in
			switch request {
			case (is PostInstance), (is PatchInstance):
				let jsonStr = """
					{
						"regEnabled": true,
						"pushRegId": "stub",
						"isPrimary": true,
						"notificationsEnabled": true
					}
"""
				return JSON.parse(jsonStr)
			default:
				return nil
			}
		}
		
		mobileMessagingInstance.remoteApiProvider.registrationQueue = MMRemoteAPIMock(
			performRequestCompanionBlock: requestPerformCompanion,
			completionCompanionBlock: nil,
			responseStub: responseStub)
		
		MobileMessaging.sharedInstance?.pushServiceToken = "stub"

		MobileMessaging.sharedInstance?.installationService.syncWithServer({ err in
			tokenSynced?.fulfill() // requestSentCounter = 0

			MobileMessaging.sharedInstance?.isPushRegistrationEnabled = false
			MobileMessaging.sharedInstance?.installationService.syncWithServer({ err in
				XCTAssertEqual(requestSentCounter, 1)
				regDisabledStatusSynced?.fulfill()

				MobileMessaging.sharedInstance?.isPushRegistrationEnabled = true
				MobileMessaging.sharedInstance?.installationService.syncWithServer({ err in
					XCTAssertEqual(requestSentCounter, 2)
					regEnabledStatusSynced?.fulfill()

					MobileMessaging.sharedInstance?.isPushRegistrationEnabled = true
					MobileMessaging.sharedInstance?.installationService.syncWithServer({ err in
						XCTAssertEqual(requestSentCounter, 2)
						regEnabled2StatusSynced?.fulfill()

					})
				})
			})
		})
		self.waitForExpectations(timeout: 60) { error in
			XCTAssertEqual(requestSentCounter, 2)
		}
	}

	func testThatRegistrationEnabledStatusIsAppliedToSubservicesStatus() {
		MMTestCase.cleanUpAndStop()
		// Message handling and Geofencing subservices must be stopped once the push reg status disabled
		// and started once push reg status enabled
		
		weak var registrationSynced = self.expectation(description: "registration synced")
		
		let responseStatusDisabledStub: (Any) -> JSON? = { request -> JSON? in
			switch request {
			case (is PostInstance), (is PatchInstance):
				let jsonStr = """
					{
						"regEnabled": false,
						"pushRegId": "stub",
						"isPrimary": true,
						"notificationsEnabled": true
					}
"""
				return JSON.parse(jsonStr)
			default:
				return nil
			}
		}

		let mm = MMTestCase.stubbedMMInstanceWithApplicationCode("stub")!.withGeofencingService()
		GeofencingService.sharedInstance = GeofencingServiceStartStopMock(mmContext: mm)
		GeofencingService.sharedInstance!.start({ _ in })
		
		mm.start()
		
		mm.remoteApiProvider.registrationQueue = MMRemoteAPIMock(
			performRequestCompanionBlock: nil,
			completionCompanionBlock: nil,
			responseStub: responseStatusDisabledStub)
		
		XCTAssertTrue(mm.messageHandler.isRunning)
		XCTAssertTrue(GeofencingService.sharedInstance!.isRunning)
		XCTAssertTrue(MobileMessaging.sharedInstance!.resolveInstallation().isPushRegistrationEnabled)
		
		mm.pushServiceToken = "stub"

		mm.installationService.syncWithServer({ err in
			// we got disabled status, now message handling must be stopped
			XCTAssertFalse(mm.messageHandler.isRunning)
			XCTAssertFalse(MobileMessaging.geofencingService!.isRunning)
			XCTAssertFalse(MobileMessaging.sharedInstance!.resolveInstallation().isPushRegistrationEnabled)
			registrationSynced?.fulfill()
		})
		self.waitForExpectations(timeout: 60, handler: nil)
	}
	
	func testThatRegistrationCleanedIfAppCodeChanged() {
		let remoteProviderMock = RemoteApiInstanceAttributesMock()
		remoteProviderMock.postInstanceClosure = { applicationCode, body, completion in
			completion(
				FetchInstanceDataResult.Success(
					Installation(applicationUserId: nil, appVersion: nil, customAttributes: nil, deviceManufacturer: nil, deviceModel: nil, deviceName: nil, deviceSecure: false, deviceTimeZone: nil, geoEnabled: false, isPrimaryDevice: true, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: nil, osVersion: nil, pushRegistrationId: "new pushRegId", pushServiceToken: "someToken".data(using: String.Encoding.utf16)!.mm_toHexString, pushServiceType: nil, sdkVersion: nil)
				)
			)
		}
		remoteProviderMock.patchInstanceClosure = { _, _, _, _, completion in
			completion(
				UpdateInstanceDataResult.Success(EmptyResponse())
			)
		}
		mobileMessagingInstance.remoteApiProvider = remoteProviderMock

		weak var finished = self.expectation(description: "finished")
		mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".data(using: String.Encoding.utf16)!) {  error in
			XCTAssertEqual(self.mobileMessagingInstance.internalData().applicationCode, MMTestConstants.kTestCorrectApplicationCode)
			XCTAssertNotNil(self.mobileMessagingInstance.resolveInstallation().pushServiceToken)
			XCTAssertNotNil(self.mobileMessagingInstance.resolveInstallation().pushRegistrationId)
			DispatchQueue.main.async {
				MMTestCase.startWithApplicationCode("newApplicationCode")
				XCTAssertEqual(self.mobileMessagingInstance.internalData().applicationCode, "newApplicationCode")
				XCTAssertNil(MobileMessaging.getInstallation()!.pushServiceToken)
				XCTAssertNil(MobileMessaging.getInstallation()!.pushRegistrationId)
				finished?.fulfill()
			}
		}

		waitForExpectations(timeout: 10, handler: nil)
	}

	func testThatRegistrationIsNotCleanedIfAppCodeChangedWhenAppCodePersistingDisabled() {
		let remoteProviderMock = RemoteApiInstanceAttributesMock()
		remoteProviderMock.postInstanceClosure = { applicationCode, body, completion in
			completion(
				FetchInstanceDataResult.Success(
					Installation(applicationUserId: nil, appVersion: nil, customAttributes: nil, deviceManufacturer: nil, deviceModel: nil, deviceName: nil, deviceSecure: false, deviceTimeZone: nil, geoEnabled: false, isPrimaryDevice: true, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: nil, osVersion: nil, pushRegistrationId: "new pushRegId", pushServiceToken: "someToken".data(using: String.Encoding.utf16)!.mm_toHexString, pushServiceType: nil, sdkVersion: nil)
				)
			)
		}
		remoteProviderMock.patchInstanceClosure = { _, _, _, _, completion in
			completion(
				UpdateInstanceDataResult.Success(EmptyResponse())
			)
		}
		mobileMessagingInstance.remoteApiProvider = remoteProviderMock

		weak var finished = self.expectation(description: "finished")

		// registration gets updated:
		mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".data(using: String.Encoding.utf16)!) {  error in

			// assertions:

			let internalData = InternalData.unarchiveCurrent()
			let installation = Installation.unarchiveCurrent()
			XCTAssertNotNil(internalData.applicationCode, "application code must be persisted")
			XCTAssertNotNil(installation.pushServiceToken)
			XCTAssertNotNil(installation.pushRegistrationId)

			DispatchQueue.main.async {

				// user want to stop persisting application code:
				MobileMessaging.privacySettings.applicationCodePersistingDisabled = true

				// user must call cleanUpAndStop manually before using newApplicationCode:
				self.mobileMessagingInstance.stop()

				// then restart with new application code:
				MMTestCase.startWithApplicationCode("newApplicationCode")

				// registration gets updated:
				self.mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".data(using: String.Encoding.utf16)!, completion: { error in

					// assertions:
					let internalDataPersisted = NSKeyedUnarchiver.unarchiveObject(withFile: InternalData.currentPath) as! InternalData
					let internalDataCached = MobileMessaging.sharedInstance!.internalData()
					XCTAssertNil(internalDataPersisted.applicationCode, "application code must not be persisted")
					XCTAssertEqual(internalDataCached.applicationCode, "newApplicationCode", "Application code available in-memory")
					finished?.fulfill()
				})
			}
		}
		waitForExpectations(timeout: 60, handler: nil)
	}

	//https://openradar.appspot.com/29489461
	func testThatExpireRequestBeingSentAfterReinstallation(){
		weak var expirationRequested = self.expectation(description: "expirationRequested")
		weak var registration2Done = self.expectation(description: "registration2Done")
		weak var registration3Done = self.expectation(description: "registration3Done")

		do {
			let remoteProviderMock = RemoteApiInstanceAttributesMock()
			remoteProviderMock.patchInstanceClosure = { applicationCode, pushRegistrationId, refPushRegistrationId, body, completion in
				completion(UpdateInstanceDataResult.Success(EmptyResponse()))
			}
			remoteProviderMock.postInstanceClosure = { applicationCode, body, completion in
				completion(FetchInstanceDataResult.Success(
					Installation(applicationUserId: nil, appVersion: nil, customAttributes: nil, deviceManufacturer: nil, deviceModel: nil, deviceName: nil, deviceSecure: false, deviceTimeZone: nil, geoEnabled: false, isPrimaryDevice: true, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: nil, osVersion: nil, pushRegistrationId: "new pushRegId", pushServiceToken: "someToken".data(using: String.Encoding.utf16)!.mm_toHexString, pushServiceType: nil, sdkVersion: nil)
				))
			}
			self.mobileMessagingInstance.remoteApiProvider = remoteProviderMock
		}

		mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".data(using: String.Encoding.utf16)!) {  error in
			XCTAssertEqual(self.mobileMessagingInstance.internalData().applicationCode, MMTestConstants.kTestCorrectApplicationCode)
			XCTAssertNotNil(self.mobileMessagingInstance.resolveInstallation().pushServiceToken)
			let firstInternalId = self.mobileMessagingInstance.resolveInstallation().pushRegistrationId
			XCTAssertNotNil(firstInternalId)

			// uninstall >
			self.mobileMessagingInstance.cleanUpAndStop(false)
			MobileMessaging.sharedInstance = nil
			// < uninstall

			// reinstall >
			MMTestCase.startWithCorrectApplicationCode()
			// < reinstall

			XCTAssertEqual(self.mobileMessagingInstance.keychain.pushRegId, firstInternalId)

			do {
				let remoteProviderMock = RemoteApiInstanceAttributesMock()
				remoteProviderMock.patchInstanceClosure = { applicationCode, pushRegistrationId, refPushRegistrationId, body, completion in
					completion(UpdateInstanceDataResult.Success(EmptyResponse()))
				}
				remoteProviderMock.postInstanceClosure = { applicationCode, body, completion in
					completion(FetchInstanceDataResult.Success(
						Installation(applicationUserId: nil, appVersion: nil, customAttributes: nil, deviceManufacturer: nil, deviceModel: nil, deviceName: nil, deviceSecure: false, deviceTimeZone: nil, geoEnabled:false, isPrimaryDevice: true, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: nil, osVersion: nil, pushRegistrationId: "new pushRegId2", pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil)
					))
				}
				self.mobileMessagingInstance.remoteApiProvider = remoteProviderMock
			}

			self.mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".data(using: String.Encoding.utf16)!) { error in
				registration2Done?.fulfill()

				// call to expire, then >
				do {
					let remoteProviderMock = RemoteApiInstanceAttributesMock()
					remoteProviderMock.deleteInstanceClosure = { applicationCode, pushReg, expiredPushRef, completion in
						XCTAssertEqual(self.mobileMessagingInstance.keychain.pushRegId, firstInternalId)
						XCTAssertEqual(expiredPushRef, firstInternalId)
						completion(UpdateInstanceDataResult.Success(EmptyResponse()))
						expirationRequested?.fulfill()
					}
					self.mobileMessagingInstance.remoteApiProvider = remoteProviderMock
				}

				// try to reasonably expire
				self.mobileMessagingInstance.installationService.syncWithServer({ _ in
					// <
					XCTAssertNotEqual(self.mobileMessagingInstance.keychain.pushRegId, firstInternalId)
					XCTAssertEqual(self.mobileMessagingInstance.keychain.pushRegId, self.mobileMessagingInstance.resolveInstallation().pushRegistrationId)

					do {
						let remoteProviderMock = RemoteApiInstanceAttributesMock()
						remoteProviderMock.deleteInstanceClosure = { applicationCode, pushReg, expiredPushRef, completion in
							XCTFail()
						}
						self.mobileMessagingInstance.remoteApiProvider = remoteProviderMock
					}

					// try to redundantly expire
					self.mobileMessagingInstance.installationService.syncWithServer({ _ in
						XCTAssertEqual(self.mobileMessagingInstance.keychain.pushRegId, self.mobileMessagingInstance.resolveInstallation().pushRegistrationId)
						registration3Done?.fulfill()
					})
				})
			}
		}

		waitForExpectations(timeout: 1000, handler: nil)
	}
}

class NotificationsEnabledMock: MMApplication {
	var applicationState: UIApplication.State { return .active }
	
	var applicationIconBadgeNumber: Int {
		get { return 0 }
		set {}
	}
	
	var isRegisteredForRemoteNotifications: Bool { return true }
	func unregisterForRemoteNotifications() {}
	func registerForRemoteNotifications() {}
	func presentLocalNotificationNow(_ notification: UILocalNotification) {}
	func registerUserNotificationSettings(_ notificationSettings: UIUserNotificationSettings) {}
	var currentUserNotificationSettings: UIUserNotificationSettings? {
		return UIUserNotificationSettings(types: .alert, categories: nil)
	}
}

class NotificationsDisabledMock: MMApplication {
	var applicationState: UIApplication.State { return .active }
	
	var applicationIconBadgeNumber: Int {
		get { return 0 }
		set {}
	}
	
	var isRegisteredForRemoteNotifications: Bool { return true }
	func unregisterForRemoteNotifications() {}
	func registerForRemoteNotifications() {}
	func presentLocalNotificationNow(_ notification: UILocalNotification) {}
	func registerUserNotificationSettings(_ notificationSettings: UIUserNotificationSettings) {}
	var currentUserNotificationSettings: UIUserNotificationSettings? {
		return UIUserNotificationSettings(types: [], categories: nil)
	}
}


class GeofencingServiceStartStopMock: GeofencingService {
	override func stop(_ completion: ((Bool) -> Void)?) {
		isRunning = false
	}
	override func start(_ completion: ((Bool) -> Void)?) {
		isRunning = true
	}
	override func authorizeService(kind: LocationServiceKind, usage: LocationServiceUsage, completion: @escaping (GeofencingCapabilityStatus) -> Void) {
		completion(.authorized)
	}
	
	override func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {}
	
	override public class var currentCapabilityStatus: GeofencingCapabilityStatus {
		return GeofencingCapabilityStatus.authorized
	}
}
