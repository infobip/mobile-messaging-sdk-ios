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
			
			let ctx = self.mobileMessagingInstance.currentInstallation.installationManager.storageContext
			if let installation = InstallationManagedObject.MM_findFirstInContext(ctx) {
				XCTAssertEqual(installationsNumber, 1, "there must be one installation object persisted")
				XCTAssertEqual(installation.deviceToken, "token\(maxCount-1)".mm_toHexademicalString(), "Most recent token must be persisted")
				XCTAssertFalse(installation.dirtyAttributesSet.contains(SyncableAttributesSet.deviceToken), "Device token must be synced with server")
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
				
				token2Saved?.fulfill()
				
				currentUser.email = MMTestConstants.kTestValidEmail
				currentUser.msisdn = MMTestConstants.kTestValidMSISDN
				
				currentUser.save { err in
					XCTAssertNil(err)
					validEmailSaved?.fulfill()
					validMsisdnSaved?.fulfill()
				}
			}
		}
        
        self.waitForExpectations(timeout: 60) { _ in
			assert(MMQueue.Main.queue.isCurrentQueue)
			let ctx = self.mobileMessagingInstance.currentInstallation.installationManager.storageContext
			if let installation = InstallationManagedObject.MM_findFirstInContext(ctx) {
			
				XCTAssertFalse(installation.dirtyAttributesSet.contains(SyncableAttributesSet.deviceToken), "current installation must be synchronized")
				XCTAssertEqual(installation.internalUserId, MMTestConstants.kTestCorrectInternalID, "internal id must be mocked properly. (current is \(installation.internalUserId))")
				XCTAssertEqual(installation.deviceToken, "someToken2".mm_toHexademicalString(), "Device token must be mocked properly. (current is \(installation.deviceToken))")
				XCTAssertEqual(installation.predefinedUserData?[MMUserPredefinedDataKeys.Email.name] as? String, MMTestConstants.kTestValidEmail, "")
				XCTAssertEqual(installation.predefinedUserData?[MMUserPredefinedDataKeys.MSISDN.name] as? String, MMTestConstants.kTestValidMSISDN, "")
				
				XCTAssertFalse(installation.dirtyAttributesSet.contains(SyncableAttributesSet.deviceToken), "")
			} else {
				XCTFail("There must be atleast one installation object in database")
			}
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
			assert(MMQueue.Main.queue.isCurrentQueue)
			let ctx = self.mobileMessagingInstance.currentInstallation.installationManager.storageContext
			if let installation = InstallationManagedObject.MM_findFirstInContext(ctx) {
			
				XCTAssertTrue(installation.dirtyAttributesSet.contains(SyncableAttributesSet.deviceToken), "Dirty flag may be false only after success registration")
				XCTAssertEqual(installation.internalUserId, nil, "Internal id must be nil, server denied the application code")
				XCTAssertEqual(installation.deviceToken, "someToken".mm_toHexademicalString(), "Device token must be mocked properly. (current is \(installation.deviceToken))")
			} else {
				XCTFail("There must be atleast one installation object in database")
			}
		}
	}
	
	var requestSentCounter = 0
    func testTokenSendsTwice() {
		MobileMessaging.userAgent = UserAgentStub()
		
		MobileMessaging.sharedInstance?.remoteApiManager.registrationQueue = MMRemoteAPIMock(baseURLString: MMTestConstants.kTestBaseURLString, appCode: MMTestConstants.kTestCorrectApplicationCode, performRequestCompanionBlock: { request in
			
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
		
		let mm = MobileMessaging.withApplicationCode("stub", notificationType: [], backendBaseURL: "stub")!.withGeofencingService()
		mm.geofencingService = GeofencingServiceStartStopMock(storage: storage)
		mm.start()
		
		mm.remoteApiManager.registrationQueue = MMRemoteAPIMock(baseURLString: MMTestConstants.kTestBaseURLString,
		                                                                             appCode: MMTestConstants.kTestWrongApplicationCode,
		                                                                             performRequestCompanionBlock: nil,
		                                                                             completionCompanionBlock: nil,
		                                                                             responseSubstitution: responseStatusDisabledStub)
		
		XCTAssertTrue(mm.messageHandler.isRunning)
		XCTAssertTrue(mm.geofencingService.isRunning)
		XCTAssertTrue(MobileMessaging.isPushRegistrationEnabled)
		
		mm.currentInstallation.deviceToken = "stub"
		mm.currentInstallation.syncInstallationWithServer(completion: { err in
			// we got disabled status, now message handling must be stopped
			XCTAssertFalse(mm.messageHandler.isRunning)
			XCTAssertFalse(mm.geofencingService.isRunning)
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
			XCTAssertNotNil(self.mobileMessagingInstance.currentUser.internalId)
			DispatchQueue.main.async {
				self.startWithApplicationCode("newApplicationCode")
				XCTAssertEqual(self.mobileMessagingInstance.currentInstallation.applicationCode, "newApplicationCode")
				XCTAssertNil(self.mobileMessagingInstance.currentInstallation.deviceToken)
				XCTAssertNil(self.mobileMessagingInstance.currentUser.internalId)
				XCTAssertNil(self.mobileMessagingInstance.keychain.internalId)
				finished?.fulfill()
			}
		}

		waitForExpectations(timeout: 10, handler: nil)
	}
	
	func testThatAfterAppReinstallInternalIdStillTheSame(){
		weak var finished1 = self.expectation(description: "finished")
		weak var finished2 = self.expectation(description: "finished")

		mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".data(using: String.Encoding.utf16)!) {  error in
			XCTAssertEqual(self.mobileMessagingInstance.currentInstallation.applicationCode, MMTestConstants.kTestCorrectApplicationCode)
			XCTAssertNotNil(self.mobileMessagingInstance.currentInstallation.deviceToken)
			let internalId = self.mobileMessagingInstance.currentUser.internalId
			XCTAssertNotNil(internalId)
			self.mobileMessagingInstance.cleanUpAndStop(false)
			MobileMessaging.sharedInstance = nil
			self.startWithCorrectApplicationCode()
			XCTAssertEqual(internalId, self.mobileMessagingInstance.keychain.internalId)

			let mock = MMRemoteAPIMock(baseURLString: MMTestConstants.kTestBaseURLString,
			                appCode: MMTestConstants.kTestCorrectApplicationCode,
			                performRequestCompanionBlock: nil,
			                completionCompanionBlock: nil,
			                responseSubstitution: nil)
			mock.performRequestCompanionBlock = { request in
				if let request = request as? RegistrationRequest {
					XCTAssertEqual(request.internalId, internalId)
					finished1?.fulfill()
				}
			}
			
			self.mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".data(using: String.Encoding.utf16)!) { error in
				finished2?.fulfill()
			}
			self.mobileMessagingInstance.remoteApiManager.registrationQueue = mock
		}
	
		waitForExpectations(timeout: 10, handler: nil)
	}
	
	//https://openradar.appspot.com/29489461
	func testThatAfterAppReinstallWithOtherAppCodeKeychainCleared(){
		weak var finished = self.expectation(description: "finished")
		mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".data(using: String.Encoding.utf16)!) {  error in
			XCTAssertEqual(self.mobileMessagingInstance.currentInstallation.applicationCode, MMTestConstants.kTestCorrectApplicationCode)
			XCTAssertNotNil(self.mobileMessagingInstance.currentInstallation.deviceToken)
			let internalId = self.mobileMessagingInstance.currentUser.internalId
			XCTAssertNotNil(internalId)
			DispatchQueue.main.async {
				self.mobileMessagingInstance.cleanUpAndStop(false)
				MobileMessaging.sharedInstance = nil
				self.startWithApplicationCode("otherApplicationCode")
				XCTAssertNil(self.mobileMessagingInstance.keychain.internalId)
				XCTAssertEqual(self.mobileMessagingInstance.keychain.get(KeychainKeys.applicationCode), "otherApplicationCode")
				finished?.fulfill()
			}
		}
		
		waitForExpectations(timeout: 10, handler: nil)
	}
}

class NotificationsEnabledMock: UIApplicationProtocol {
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

class NotificationsDisabledMock: UIApplicationProtocol {
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


class GeofencingServiceStartStopMock: MMGeofencingService {
	override func stop(_ completion: ((Bool) -> Void)?) {
		isRunning = false
	}
	override func start(_ completion: ((Bool) -> Void)?) {
		isRunning = true
	}
	override func authorizeService(kind: MMLocationServiceKind, usage: MMLocationServiceUsage, completion: @escaping (MMCapabilityStatus) -> Void) {
		completion(.Authorized)
	}
	
	override func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {}
}
