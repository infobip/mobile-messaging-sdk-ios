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
				XCTAssertEqual(installation.deviceToken, "token\(maxCount-1)".mm_toHexademicalString, "Most recent token must be persisted")
				XCTAssertFalse(installation.dirtyAttributesSet.contains(AttributesSet.deviceToken), "Device token must be synced with server")
			} else {
				XCTFail("There must be atleast one installation object in database")
			}
		})
    }

    func testRegisterForRemoteNotificationsWithDeviceToken() {
		guard let currentUser = MobileMessaging.currentUser else {
			XCTFail("Installation not initialized")
			return
		}
		
        weak var token2Saved = expectation(description: "token2 saved")
		weak var validEmailSaved = expectation(description: "email saved")
		weak var validMsisdnSaved = expectation(description: "msisdn saved")
		
		mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".data(using: String.Encoding.utf16)!) {  error in
		
			self.mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken2".data(using: String.Encoding.utf16)!) {  error in
				
				currentUser.email = MMTestConstants.kTestValidEmail
				currentUser.msisdn = MMTestConstants.kTestValidMSISDN
				
				currentUser.save { err in
					XCTAssertNil(err)
					validEmailSaved?.fulfill()
					validMsisdnSaved?.fulfill()
				}
				
				token2Saved?.fulfill()
			}
		}
        
        self.waitForExpectations(timeout: 60) { _ in
			
			XCTAssertFalse(self.mobileMessagingInstance.currentInstallation.isRegistrationStatusNeedSync)
			XCTAssertEqual(self.mobileMessagingInstance.currentInstallation.deviceToken, "someToken2".mm_toHexademicalString)
			XCTAssertEqual(self.mobileMessagingInstance.currentUser.pushRegistrationId, MMTestConstants.kTestCorrectInternalID)
			XCTAssertEqual(self.mobileMessagingInstance.currentUser.email, MMTestConstants.kTestValidEmail)
			XCTAssertEqual(self.mobileMessagingInstance.currentUser.msisdn, MMTestConstants.kTestValidMSISDN)
        }
    }
	
	func testWrongApplicationCode() {
		
		cleanUpAndStop()
		startWithWrongApplicationCode()
		
		weak var expectation = self.expectation(description: "Installation data updating")
		mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".data(using: String.Encoding.utf16)!) {  error in
			expectation?.fulfill()
		}
		self.waitForExpectations(timeout: 60) { _ in
			let ctx = (self.mobileMessagingInstance.internalStorage.mainThreadManagedObjectContext!)
			if let installation = InstallationManagedObject.MM_findFirstInContext(ctx) {
				XCTAssertTrue(installation.dirtyAttributesSet.contains(AttributesSet.deviceToken), "Dirty flag may be false only after success registration")
				XCTAssertEqual(installation.internalUserId, nil, "Internal id must be nil, server denied the application code")
				XCTAssertEqual(installation.deviceToken, "someToken".mm_toHexademicalString, "Device token must be stubbed properly. (current is \(String(describing: installation.deviceToken)))")
			} else {
				XCTFail("There must be atleast one installation object in database")
			}
		}
	}
	
	var requestSentCounter = 0
    func testTokenSendsTwice() {
		MobileMessaging.userAgent = UserAgentStub()
		
		MobileMessaging.sharedInstance?.remoteApiManager.registrationQueue = MMRemoteAPIMock(baseURLString: MMTestConstants.kTestBaseURLString, appCode: MMTestConstants.kTestCorrectApplicationCode, mmContext: self.mobileMessagingInstance, performRequestCompanionBlock: { request in
			
			switch request {
			case (is RegistrationRequest):
				DispatchQueue.main.async {
					self.requestSentCounter += 1
				}
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
			XCTAssertEqual(self.requestSentCounter, 2)
        }
    }
	
    func testRegistrationDataNotSendsWithoutToken() {
        weak var syncInstallationWithServer = expectation(description: "sync1")
		var requestSentCounter = 0
		let requestPerformCompanion: (Any) -> Void = { request in
			if let _ = request as? RegistrationRequest {
				DispatchQueue.main.async {
					requestSentCounter += 1
				}
			}
		}
		mobileMessagingInstance.remoteApiManager.registrationQueue = MMRemoteAPIMock(baseURLString: MMTestConstants.kTestBaseURLString,
																					  appCode: MMTestConstants.kTestWrongApplicationCode,
																					  mmContext: self.mobileMessagingInstance,
																					  performRequestCompanionBlock: requestPerformCompanion,
																					  completionCompanionBlock: nil,
																					  responseSubstitution: nil)
		
		if MobileMessaging.currentInstallation == nil {
			XCTFail("Installation is nil")
			syncInstallationWithServer?.fulfill()
		}
		
        MobileMessaging.currentInstallation?.syncInstallationWithServer(completion: { (error) -> Void in
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
			if let request = request as? RegistrationRequest, request.isEnabled != nil {
				DispatchQueue.main.async {
					requestSentCounter += 1
				}
			}
		}
		
		let responseStub: (Any) -> JSON? = { request -> JSON? in
			if let request = request as? RegistrationRequest {
				let isEnabled = request.isEnabled ?? true
				let jsonStr = "{\"pushRegistrationEnabled\": \(isEnabled ? "true": "false")," +
					"\"deviceApplicationInstanceId\": \"stub\"," +
					"\"registrationId\": \"stub\"," +
				"\"platformType\": \"string\"}"
				return JSON.parse(jsonStr)
			} else {
				return nil
			}
		}
		
		mobileMessagingInstance.remoteApiManager.registrationQueue = MMRemoteAPIMock(baseURLString: MMTestConstants.kTestBaseURLString,
		                                                                              appCode: MMTestConstants.kTestWrongApplicationCode,
		                                                                              mmContext: self.mobileMessagingInstance,
		                                                                              performRequestCompanionBlock: requestPerformCompanion,
		                                                                              completionCompanionBlock: nil,
		                                                                              responseSubstitution: responseStub)
		
		self.mobileMessagingInstance.currentInstallation.deviceToken = "stub"
		self.mobileMessagingInstance.currentInstallation.syncInstallationWithServer(completion: { err in
			tokenSynced?.fulfill() // requestSentCounter = 0
			
			MobileMessaging.disablePushRegistration() { err in
				regDisabledStatusSynced?.fulfill() // requestSentCounter + 1 (1)
				
				MobileMessaging.enablePushRegistration() { err in
					regEnabledStatusSynced?.fulfill() // requestSentCounter + 1 (2)
					
					MobileMessaging.enablePushRegistration() { err in
						regEnabled2StatusSynced?.fulfill() // requestSentCounter same (2)
					}
				}
			}
		})
		self.waitForExpectations(timeout: 60) { error in
			XCTAssertEqual(requestSentCounter, 2)
		}
	}

	func testThatRegistrationEnabledStatusIsAppliedToSubservicesStatus() {
		cleanUpAndStop()
		// Message handling and Geofencing subservices must be stopped once the push reg status disabled
		// and started once push reg status enabled
		
		weak var registrationSynced = self.expectation(description: "registration synced")
		
		let responseStatusDisabledStub: (Any) -> JSON? = { request -> JSON? in
			if request is RegistrationRequest {
				let jsonStr = "{\"pushRegistrationEnabled\": false," +
					"\"deviceApplicationInstanceId\": \"stub\"," +
					"\"registrationId\": \"stub\"," +
				"\"platformType\": \"string\"}"
				return JSON.parse(jsonStr)
			} else {
				return nil
			}
		}

		let mm = stubbedMMInstanceWithApplicationCode("stub")!.withGeofencingService()
		GeofencingService.sharedInstance = GeofencingServiceStartStopMock(mmContext: mm)
		GeofencingService.sharedInstance!.start()
		
		mm.start()
		
		mm.remoteApiManager.registrationQueue = MMRemoteAPIMock(baseURLString: MMTestConstants.kTestBaseURLString,
		                                                                             appCode: MMTestConstants.kTestWrongApplicationCode,
		                                                                             mmContext: mm,
		                                                                             performRequestCompanionBlock: nil,
		                                                                             completionCompanionBlock: nil,
		                                                                             responseSubstitution: responseStatusDisabledStub)
		
		XCTAssertTrue(mm.messageHandler.isRunning)
		XCTAssertTrue(GeofencingService.sharedInstance!.isRunning)
		XCTAssertTrue(MobileMessaging.isPushRegistrationEnabled)
		
		mm.currentInstallation.deviceToken = "stub"
		mm.currentInstallation.syncInstallationWithServer(completion: { err in
			// we got disabled status, now message handling must be stopped
			XCTAssertFalse(mm.messageHandler.isRunning)
			XCTAssertFalse(MobileMessaging.geofencingService!.isRunning)
			XCTAssertFalse(MobileMessaging.isPushRegistrationEnabled)
			registrationSynced?.fulfill()
		})
		self.waitForExpectations(timeout: 60, handler: nil)
	}
	
	func testThatRegistrationCleanedIfAppCodeChanged() {
		weak var finished = self.expectation(description: "finished")
		mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".data(using: String.Encoding.utf16)!) {  error in
			XCTAssertEqual(self.mobileMessagingInstance.currentInstallation.applicationCode, MMTestConstants.kTestCorrectApplicationCode)
			XCTAssertNotNil(self.mobileMessagingInstance.currentInstallation.deviceToken)
			XCTAssertNotNil(self.mobileMessagingInstance.currentUser.pushRegistrationId)
			DispatchQueue.main.async {
				self.startWithApplicationCode("newApplicationCode")
				XCTAssertEqual(self.mobileMessagingInstance.currentInstallation.applicationCode, "newApplicationCode")
				XCTAssertNil(self.mobileMessagingInstance.currentInstallation.deviceToken)
				XCTAssertNil(self.mobileMessagingInstance.currentUser.pushRegistrationId)
				finished?.fulfill()
			}
		}

		waitForExpectations(timeout: 10, handler: nil)
	}
	
	func testThatRegistrationIsNotCleanedIfAppCodeChangedWhenAppCodePersistingDisabled() {
	
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
			XCTAssertNotNil(self.mobileMessagingInstance.currentUser.pushRegistrationId)
			
			DispatchQueue.main.async {
				
				// user want to stop persisting application code:
				MobileMessaging.privacySettings.applicationCodePersistingDisabled = true
				
				// user must call cleanUpAndStop manually before using newApplicationCode:
				self.mobileMessagingInstance.cleanUpAndStop()
				
				// then restart with new application code:
				self.startWithApplicationCode("newApplicationCode")
				
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
		weak var registrationRequest2MockDone = self.expectation(description: "registrationRequestMockDone")
		weak var registrationRequest3MockDone = self.expectation(description: "registrationRequestMockDone")
		weak var registration2Done = self.expectation(description: "registration2Done")
		weak var registration3Done = self.expectation(description: "registration3Done")
		
		mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".data(using: String.Encoding.utf16)!) {  error in
			XCTAssertEqual(self.mobileMessagingInstance.currentInstallation.applicationCode, MMTestConstants.kTestCorrectApplicationCode)
			XCTAssertNotNil(self.mobileMessagingInstance.currentInstallation.deviceToken)
			let firstInternalId = self.mobileMessagingInstance.currentUser.pushRegistrationId
			XCTAssertNotNil(firstInternalId)
			
			self.mobileMessagingInstance.cleanUpAndStop(false)
			MobileMessaging.sharedInstance = nil
			self.startWithCorrectApplicationCode()
			
			XCTAssertEqual(firstInternalId, self.mobileMessagingInstance.keychain.internalId)
			
			let reg2mock = MMRemoteAPIMock(baseURLString: MMTestConstants.kTestBaseURLString,
			                           appCode: MMTestConstants.kTestCorrectApplicationCode,
			                           mmContext: self.mobileMessagingInstance,
			                           performRequestCompanionBlock: nil,
			                           completionCompanionBlock: nil,
			                           responseSubstitution: nil)
			reg2mock.performRequestCompanionBlock = { request in
				if let request = request as? RegistrationRequest {
					//TODO: implement networking mocks on NSURLProtocol
//					XCTAssertEqual(request.pushRegistrationIdHeader, "unregistered")
					XCTAssertEqual(self.mobileMessagingInstance.keychain.internalId, firstInternalId)
					XCTAssertEqual(request.expiredInternalId, firstInternalId)
					registrationRequest2MockDone?.fulfill()
				}
			}
			self.mobileMessagingInstance.remoteApiManager.registrationQueue = reg2mock
			
			self.mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".data(using: String.Encoding.utf16)!) { error in
				XCTAssertNotEqual(self.mobileMessagingInstance.keychain.internalId, firstInternalId)
				XCTAssertEqual(self.mobileMessagingInstance.keychain.internalId, self.mobileMessagingInstance.currentUser.pushRegistrationId)
				registration2Done?.fulfill()
				
				
				let reg3mock = MMRemoteAPIMock(baseURLString: MMTestConstants.kTestBaseURLString,
				                           appCode: MMTestConstants.kTestCorrectApplicationCode,
				                           mmContext: self.mobileMessagingInstance,
				                           performRequestCompanionBlock: nil,
				                           completionCompanionBlock: nil,
				                           responseSubstitution: nil)
				
				reg3mock.performRequestCompanionBlock = { request in
					if let request = request as? RegistrationRequest {
						//TODO: implement networking mocks on NSURLProtocol
//						XCTAssertNotEqual(request.pushRegistrationIdHeader, "unregistered")
//						XCTAssertEqual(request.pushRegistrationIdHeader, self.mobileMessagingInstance.keychain.internalId)
						XCTAssertNil(request.expiredInternalId)
						registrationRequest3MockDone?.fulfill()
					}
				}
				self.mobileMessagingInstance.remoteApiManager.registrationQueue = reg3mock
				
				self.mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".data(using: String.Encoding.utf16)!) { error in
					
					XCTAssertEqual(self.mobileMessagingInstance.keychain.internalId, self.mobileMessagingInstance.currentUser.pushRegistrationId)
					registration3Done?.fulfill()
				}
			}
		}
		
		waitForExpectations(timeout: 10, handler: nil)
	}
}

class NotificationsEnabledMock: MMApplication {
	var applicationState: UIApplicationState { return .active }
	
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
	var applicationState: UIApplicationState { return .active }
	
	var applicationIconBadgeNumber: Int {
		get { return 0 }
		set {}
	}
	
	var isRegisteredForRemoteNotifications: Bool { return true }
	func unregisterForRemoteNotifications() {}
	func registerForRemoteNotifications() {}
	func presentLocalNotificationNow(_ notification: UILocalNotification) {}
	func registerUserNotificationSettings(_ notificationSettings: UIUserNotificationSettings) {}
	var currentUserNotificationSettings: UIUserNotificationSettings? { return UIUserNotificationSettings(types: [], categories: nil) }
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
