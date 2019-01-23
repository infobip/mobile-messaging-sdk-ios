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
	
	func testInstallationPersisting() {
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

		for counter in 0..<maxCount {
			let deviceToken = "token\(counter)".data(using: String.Encoding.utf16)
			mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken!) { error in
				if counter == maxCount - 1 {
					tokensexp?.fulfill()
				}
			}
		}
		
		waitForExpectations(timeout: 100, handler: { err in
			let installationsNumber = InstallationManagedObject.MM_countOfEntitiesWithContext(self.storage.mainThreadManagedObjectContext!)
			
			let ctx = (self.mobileMessagingInstance.internalStorage.mainThreadManagedObjectContext!)
			if let installation = InstallationManagedObject.MM_findFirstInContext(ctx) {
				XCTAssertEqual(installationsNumber, 1, "there must be one installation object persisted")
				XCTAssertEqual(installation.pushServiceToken, "token\(maxCount-1)".mm_toHexademicalString, "Most recent token must be persisted")
				XCTAssertFalse(installation.dirtyAttsSet.contains(Attributes.pushServiceToken), "Device token must be synced with server")
			} else {
				XCTFail("There must be atleast one installation object in database")
			}
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
			XCTAssertFalse(self.mobileMessagingInstance.currentInstallation.isRegistrationStatusNeedSync)
			XCTAssertEqual(self.mobileMessagingInstance.currentInstallation.deviceToken, "someToken2".mm_toHexademicalString)
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
			let ctx = (self.mobileMessagingInstance.internalStorage.mainThreadManagedObjectContext!)
			if let installation = InstallationManagedObject.MM_findFirstInContext(ctx) {
				XCTAssertTrue(installation.dirtyAttsSet.contains(Attributes.pushServiceToken), "Dirty flag may be false only after success registration")
				XCTAssertEqual(installation.pushRegId, nil, "Internal id must be nil, server denied the application code")
				XCTAssertEqual(installation.pushServiceToken, "someToken".mm_toHexademicalString, "Device token must be stubbed properly. (current is \(String(describing: installation.pushServiceToken)))")
			} else {
				XCTFail("There must be atleast one installation object in database")
			}
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
			responseSubstitution: nil)
		
		if MobileMessaging.currentInstallation == nil {
			XCTFail("Installation is nil")
		}

		MobileMessaging.currentInstallation?.syncWithServer({ (error) -> Void in
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
			responseSubstitution: responseStub)
		
		MobileMessaging.currentInstallation?.deviceToken = "stub"
		MobileMessaging.currentInstallation?.persist()
		MobileMessaging.currentInstallation?.syncWithServer({ err in
			tokenSynced?.fulfill() // requestSentCounter = 0

			MobileMessaging.currentInstallation?.isPushRegistrationEnabled = false
			MobileMessaging.currentInstallation?.persist()
			MobileMessaging.currentInstallation?.syncWithServer({ err in
				regDisabledStatusSynced?.fulfill() // requestSentCounter + 1 (1)

				MobileMessaging.currentInstallation?.isPushRegistrationEnabled = true
				MobileMessaging.currentInstallation?.persist()
				MobileMessaging.currentInstallation?.syncWithServer({ err in
					regEnabledStatusSynced?.fulfill() // requestSentCounter + 1 (2)

					MobileMessaging.currentInstallation?.isPushRegistrationEnabled = true
					MobileMessaging.currentInstallation?.persist()
					MobileMessaging.currentInstallation?.syncWithServer({ err in
						regEnabled2StatusSynced?.fulfill() // requestSentCounter same (2)
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
			responseSubstitution: responseStatusDisabledStub)
		
		XCTAssertTrue(mm.messageHandler.isRunning)
		XCTAssertTrue(GeofencingService.sharedInstance!.isRunning)
		XCTAssertTrue(MobileMessaging.currentInstallation!.isPushRegistrationEnabled)
		
		mm.currentInstallation.deviceToken = "stub"
		mm.currentInstallation.persist()
		mm.currentInstallation.syncWithServer({ err in
			// we got disabled status, now message handling must be stopped
			XCTAssertFalse(mm.messageHandler.isRunning)
			XCTAssertFalse(MobileMessaging.geofencingService!.isRunning)
			XCTAssertFalse(MobileMessaging.currentInstallation!.isPushRegistrationEnabled)
			registrationSynced?.fulfill()
		})
		self.waitForExpectations(timeout: 60, handler: nil)
	}
	
	func testThatRegistrationCleanedIfAppCodeChanged() {
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

		weak var finished = self.expectation(description: "finished")
		mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".data(using: String.Encoding.utf16)!) {  error in
			XCTAssertEqual(self.mobileMessagingInstance.currentInstallation.applicationCode, MMTestConstants.kTestCorrectApplicationCode)
			XCTAssertNotNil(self.mobileMessagingInstance.currentInstallation.deviceToken)
			XCTAssertNotNil(self.mobileMessagingInstance.currentInstallation.pushRegistrationId)
			DispatchQueue.main.async {
				MMTestCase.startWithApplicationCode("newApplicationCode")
				XCTAssertEqual(self.mobileMessagingInstance.currentInstallation.applicationCode, "newApplicationCode")
				XCTAssertNil(self.mobileMessagingInstance.currentInstallation.deviceToken)
				XCTAssertNil(self.mobileMessagingInstance.currentInstallation.pushRegistrationId)
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

		weak var finished = self.expectation(description: "finished")
		
		// registration gets updated:
		mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".data(using: String.Encoding.utf16)!) {  error in
			
			// assertions:
			let ctx = self.mobileMessagingInstance.currentInstallation.coreDataProvider.context
			ctx.performAndWait {
				let installation = InstallationManagedObject.MM_findFirstInContext(ctx)!
				XCTAssertNotNil(installation.applicationCode, "application code must be persisted")
			}
			XCTAssertNotNil(self.mobileMessagingInstance.currentInstallation.deviceToken)
			XCTAssertNotNil(self.mobileMessagingInstance.currentInstallation.pushRegistrationId)
			
			DispatchQueue.main.async {
				
				// user want to stop persisting application code:
				MobileMessaging.privacySettings.applicationCodePersistingDisabled = true
				
				// user must call cleanUpAndStop manually before using newApplicationCode:
				self.mobileMessagingInstance.cleanUpAndStop()
				
				// then restart with new application code:
				MMTestCase.startWithApplicationCode("newApplicationCode")
				
				// registration gets updated:
				self.mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".data(using: String.Encoding.utf16)!, completion: { error in
					
					// assertions:
					let ctx = self.mobileMessagingInstance.currentInstallation.coreDataProvider.context
					ctx.performAndWait {
						let installation = InstallationManagedObject.MM_findFirstInContext(ctx)!
						XCTAssertNil(installation.applicationCode, "application code must not be persisted")
					}
					XCTAssertEqual(self.mobileMessagingInstance.currentInstallation.applicationCode, "newApplicationCode", "Application code available in-memory")
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
					Installation(applicationUserId: nil, appVersion: nil, customAttributes: nil, deviceManufacturer: nil, deviceModel: nil, deviceName: nil, deviceSecure: false, deviceTimeZone: nil, geoEnabled: false, isPrimaryDevice: true, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: nil, osVersion: nil, pushRegistrationId: "new pushRegId", pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil)
				))
			}
			self.mobileMessagingInstance.remoteApiProvider = remoteProviderMock
		}

		mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".data(using: String.Encoding.utf16)!) {  error in
			XCTAssertEqual(self.mobileMessagingInstance.currentInstallation.applicationCode, MMTestConstants.kTestCorrectApplicationCode)
			XCTAssertNotNil(self.mobileMessagingInstance.currentInstallation.deviceToken)
			let firstInternalId = self.mobileMessagingInstance.currentInstallation.pushRegistrationId
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
				self.mobileMessagingInstance.currentInstallation.syncWithServer({ _ in
					// <
					XCTAssertNotEqual(self.mobileMessagingInstance.keychain.pushRegId, firstInternalId)
					XCTAssertEqual(self.mobileMessagingInstance.keychain.pushRegId, self.mobileMessagingInstance.currentInstallation.pushRegistrationId)

					do {
						let remoteProviderMock = RemoteApiInstanceAttributesMock()
						remoteProviderMock.deleteInstanceClosure = { applicationCode, pushReg, expiredPushRef, completion in
							XCTFail()
						}
						self.mobileMessagingInstance.remoteApiProvider = remoteProviderMock
					}

					// try to redundantly expire
					self.mobileMessagingInstance.currentInstallation.syncWithServer({ _ in
						XCTAssertEqual(self.mobileMessagingInstance.keychain.pushRegId, self.mobileMessagingInstance.currentInstallation.pushRegistrationId)
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
	var currentUserNotificationSettings: UIUserNotificationSettings? { return UIUserNotificationSettings(types: .alert, categories: nil) }
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
	var currentUserNotificationSettings: UIUserNotificationSettings? { return nil /*UIUserNotificationSettings(types: [], categories: nil)*/ }
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
