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
	
    func testThatNoRegistrationErrorResetsRegistration() {
        MMTestCase.startWithCorrectApplicationCode()
        
        weak var errorHandled = self.expectation(description: "errorHandled")
        weak var userFetchingFinished = self.expectation(description: "userFetchingFinished")
        mobileMessagingInstance.pushRegistrationId = "rand"
        mobileMessagingInstance.pushServiceToken = "stub"
        
        let jsonStr = """
        {
            "requestError": {
                "serviceException" : {
                    "messageId" : "NO_REGISTRATION",
                    "text" : "something"
                }
            }
        }
    """
        let requestError = MMRequestError(json: JSON.parse(jsonStr))
        
        let remoteApiProvider = RemoteAPIProvider(sessionManager: SessionManagerStubBase(getDataResponseClosure: { requestData, completion in
            if requestData is GetUser {
                completion(nil, requestError?.foundationError)
                return true
            }
            return false
        }))
        mobileMessagingInstance.remoteApiProvider = remoteApiProvider
        
        MobileMessaging.fetchUser { (user, error) in
            userFetchingFinished?.fulfill()
            XCTAssertNotNil(error)
            XCTAssertEqual(error?.mm_code, "NO_REGISTRATION")
        }
        
        //wait until notification center delivers API Error notification to IntallationDataService
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(1000), execute: {
            XCTAssertNil(self.mobileMessagingInstance.dirtyInstallation().pushRegistrationId)
            XCTAssertNil(self.mobileMessagingInstance.currentInstallation().pushRegistrationId)
            
            XCTAssertNotNil(self.mobileMessagingInstance.dirtyInstallation().pushServiceToken)
            errorHandled?.fulfill()
        })
        waitForExpectations(timeout: 15, handler: nil)
    }
    
	func testInstanceDataFetchingDecoding() {
        MMTestCase.startWithCorrectApplicationCode()
        
		weak var expectation = self.expectation(description: "data fetched")
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		let expectedCustomAtts: NSDictionary  = [
			"Manufacturer" : "_Apple_",
			"Model": NSNumber(value: 1),
			"ReleaseDate": darthVaderDateOfDeath
		]
		
		let remoteApiProvider = RemoteAPIProviderStub()
		remoteApiProvider.getInstanceClosure = { appcode, pushreg -> FetchInstanceDataResult in
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
			
			return FetchInstanceDataResult.Success(MMInstallation(json: JSON.parse(jsonStr))!)
		}
		mobileMessagingInstance.remoteApiProvider = remoteApiProvider
		
        mobileMessagingInstance.installationService.fetchFromServer(userInitiated: true, completion: { (installation, error) in
			XCTAssertNil(error)
			XCTAssertEqual(installation.pushRegistrationId, MMTestConstants.kTestCorrectInternalID)
			XCTAssertEqual(installation.isPrimaryDevice, true)
			XCTAssertEqual(installation.isPushRegistrationEnabled, true)
			XCTAssertEqual(installation.applicationUserId, "appUserId")
			XCTAssertEqual(installation.customAttributes as NSDictionary, expectedCustomAtts)
			expectation?.fulfill()
		})
		
		waitForExpectations(timeout: 20, handler: nil)
	}
	
	func testInstanceDataFetchingMustBeIgnoredIfPushRegIdDifferent() {
        MMTestCase.startWithCorrectApplicationCode()
        
		weak var expectation = self.expectation(description: "data fetched")
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID

		let remoteApiProvider = RemoteAPIProviderStub()
		remoteApiProvider.getInstanceClosure = { appcode, pushreg -> FetchInstanceDataResult in
			let jsonStr = """
				{
				"pushRegId": "differentPushRegId",
				"applicationUserId": "appUserId"
				}
				"""

			return FetchInstanceDataResult.Success(MMInstallation(json: JSON.parse(jsonStr))!)
		}
		mobileMessagingInstance.remoteApiProvider = remoteApiProvider

        mobileMessagingInstance.installationService.fetchFromServer(userInitiated: true, completion: { (installation, error) in
			XCTAssertNil(error)
			XCTAssertEqual(installation.pushRegistrationId, MMTestConstants.kTestCorrectInternalID)
			XCTAssertEqual(installation.applicationUserId, nil)
			expectation?.fulfill()
		})

		waitForExpectations(timeout: 20, handler: nil)
	}

	func testInstallationPersisting() {
        MMTestCase.startWithCorrectApplicationCode()
        
		XCTAssertNil(self.mobileMessagingInstance.resolveInstallation().pushServiceToken)

		weak var tokensexp = expectation(description: "device tokens saved")
		let maxCount = 2

		let remoteProviderMock = RemoteAPIProviderStub()
		remoteProviderMock.postInstanceClosure = { _, _ -> FetchInstanceDataResult in
			return	FetchInstanceDataResult.Success(MMInstallation(applicationUserId: nil, appVersion: nil, customAttributes: [:], deviceManufacturer: nil, deviceModel: nil, deviceName: nil, deviceSecure: false, deviceTimeZone: nil, geoEnabled: false, isPrimaryDevice: true, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: nil, osVersion: nil, pushRegistrationId: "new pushRegId", pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil))
		}
		remoteProviderMock.patchInstanceClosure = { _, _, _, _ -> UpdateInstanceDataResult in
			return UpdateInstanceDataResult.Success(EmptyResponse())
		}
		mobileMessagingInstance.remoteApiProvider = remoteProviderMock

		for counter in 0..<maxCount {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(counter * 100)) {
                let deviceToken = "token\(counter)".data(using: String.Encoding.utf16)

                self.mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken(userInitiated: false, token: deviceToken!) { error in
                    if counter == maxCount - 1 {
                        tokensexp?.fulfill()
                    }
                }
            }
        }

		waitForExpectations(timeout: 100, handler: { err in
			XCTAssertEqual(self.mobileMessagingInstance.resolveInstallation().pushServiceToken, "token\(maxCount-1)".mm_toHexademicalString, "Most recent token must be persisted")
			XCTAssertNil(MMInstallation.delta?["pushServiceToken"])
		})
	}

	func testPushRegIdAvailableOnRegistrationUpdatedNotification_regression() {
        MMTestCase.startWithCorrectApplicationCode()
        
		// preconditions
		weak var tokensexp = expectation(description: "device tokens saved")
		let deviceToken = "token".data(using: String.Encoding.utf16)

		let remoteProviderMock = RemoteAPIProviderStub()
		remoteProviderMock.postInstanceClosure = { _, _ -> FetchInstanceDataResult in
			return FetchInstanceDataResult.Success(MMInstallation(applicationUserId: nil, appVersion: nil, customAttributes: [:], deviceManufacturer: nil, deviceModel: nil, deviceName: nil, deviceSecure: false, deviceTimeZone: nil, geoEnabled: false, isPrimaryDevice: true, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: nil, osVersion: nil, pushRegistrationId: "new pushRegId", pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil))
		}
		mobileMessagingInstance.remoteApiProvider = remoteProviderMock

		// assetion
		expectation(forNotification: NSNotification.Name(rawValue: MMNotificationRegistrationUpdated), object: nil) { (n) -> Bool in
			XCTAssertNotNil(MobileMessaging.getInstallation()!.pushRegistrationId)
			return true
		}

		// actions
        self.mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken(userInitiated: false, token: deviceToken!) { error in
			tokensexp?.fulfill()
		}

		waitForExpectations(timeout: 100, handler: { err in })
	}

	func testRegisterForRemoteNotificationsWithDeviceToken() {
        MMTestCase.startWithCorrectApplicationCode()
        
		weak var token2Saved = expectation(description: "token2 saved")

		let remoteProviderMock = RemoteAPIProviderStub()
		remoteProviderMock.postInstanceClosure = { _, _ -> FetchInstanceDataResult in
			return FetchInstanceDataResult.Success(
                MMInstallation(applicationUserId: nil, appVersion: nil, customAttributes: [:], deviceManufacturer: nil, deviceModel: nil, deviceName: nil, deviceSecure: false, deviceTimeZone: nil, geoEnabled: false, isPrimaryDevice: true, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: nil, osVersion: nil, pushRegistrationId: "new pushRegId", pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil)
			)
		}
		remoteProviderMock.patchInstanceClosure = { _, _, _, _ -> UpdateInstanceDataResult in
			return UpdateInstanceDataResult.Success(EmptyResponse())
		}
		mobileMessagingInstance.remoteApiProvider = remoteProviderMock

        mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken(userInitiated: false, token: "someToken".data(using: String.Encoding.utf16)!) {  error in
            self.mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken(userInitiated: false, token: "someToken2".data(using: String.Encoding.utf16)!) {  error in
				token2Saved?.fulfill()
			}
		}

		self.waitForExpectations(timeout: 60) { _ in
			XCTAssertFalse(self.mobileMessagingInstance.isRegistrationStatusNeedSync)
			XCTAssertEqual(self.mobileMessagingInstance.currentInstallation().pushServiceToken, "someToken2".mm_toHexademicalString)
		}
	}

	func testWrongApplicationCode() {
		MMTestCase.startWithWrongApplicationCode()

		let remoteProviderMock = RemoteAPIProviderStub()
		remoteProviderMock.postInstanceClosure = { _, _ -> FetchInstanceDataResult in
			return FetchInstanceDataResult.Failure(NSError(type: .UnknownError))
		}
		remoteProviderMock.patchInstanceClosure = { _, _, _, _ -> UpdateInstanceDataResult in
			return UpdateInstanceDataResult.Success(EmptyResponse())
		}
		mobileMessagingInstance.remoteApiProvider = remoteProviderMock

		weak var expectation = self.expectation(description: "Installation data updating")
        mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken(userInitiated: false, token: "someToken".data(using: String.Encoding.utf16)!) {  error in
			expectation?.fulfill()
		}
		self.waitForExpectations(timeout: 60) { _ in
			XCTAssertNotNil(MMInstallation.delta!["pushServiceToken"])
			XCTAssertNil(self.mobileMessagingInstance.resolveInstallation().pushRegistrationId)
			XCTAssertEqual(self.mobileMessagingInstance.resolveInstallation().pushServiceToken, "someToken".mm_toHexademicalString)
		}
	}

	func testTokenSendsTwice() {
        MMTestCase.startWithCorrectApplicationCode()
        
		var requestSentCounter = 0
		MobileMessaging.userAgent = UserAgentStub()

		let remoteApiProvider = RemoteAPIProviderStub()
		remoteApiProvider.postInstanceClosure = { _, _ -> FetchInstanceDataResult in
			requestSentCounter += 1
			return FetchInstanceDataResult.Success(MMInstallation.empty)
		}
		remoteApiProvider.patchInstanceClosure = { _, _, _, _ -> UpdateInstanceDataResult in
			requestSentCounter += 1
			return UpdateInstanceDataResult.Success(EmptyResponse())
		}
		MobileMessaging.sharedInstance?.remoteApiProvider = remoteApiProvider

		weak var expectation1 = expectation(description: "notification1")
		weak var expectation2 = expectation(description: "notification2")

        mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken(userInitiated: false, token: "someToken".data(using: String.Encoding.utf16)!) {  error in
			XCTAssertNil(error)
			expectation1?.fulfill()

            self.mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken(userInitiated: false, token: "someToken".data(using: String.Encoding.utf16)!) {  error in
				XCTAssertNil(error)
				expectation2?.fulfill()
			}
		}

		self.waitForExpectations(timeout: 60) { error in
			XCTAssertEqual(requestSentCounter, 2)
		}
	}

	func testRegistrationDataNotSendsWithoutToken() {
        MMTestCase.startWithCorrectApplicationCode()
        
		weak var syncInstallationWithServer = expectation(description: "sync1")
		var requestSentCounter = 0

		let remoteApiProvider = RemoteAPIProviderStub()
		remoteApiProvider.postInstanceClosure = { _, _ -> FetchInstanceDataResult in
			requestSentCounter += 1
			return FetchInstanceDataResult.Success(MMInstallation.empty)
		}
		remoteApiProvider.patchInstanceClosure = { _, _, _, _ -> UpdateInstanceDataResult in
			requestSentCounter += 1
			return UpdateInstanceDataResult.Success(EmptyResponse())
		}
		MobileMessaging.sharedInstance?.remoteApiProvider = remoteApiProvider

		if MobileMessaging.currentInstallation == nil {
			XCTFail("Installation is nil")
		}

		MobileMessaging.sharedInstance?.installationService.syncWithServer(userInitiated: true) { (error) -> Void in
			syncInstallationWithServer?.fulfill()
		}

		self.waitForExpectations(timeout: 60, handler: { err in
			XCTAssertEqual(requestSentCounter, 0)
		})
	}

	func testThatRegistrationEnabledStatusIsBeingSyncedAfterChanged() {
        MMTestCase.startWithCorrectApplicationCode()
        
		weak var tokenSynced = self.expectation(description: "registration sent")
		weak var regDisabledStatusSynced = self.expectation(description: "registration sent")
		weak var regEnabledStatusSynced = self.expectation(description: "registration sent")
		weak var regEnabled2StatusSynced = self.expectation(description: "registration sent")

		var requestSentCounter = 0
		let stubInstallation = MMInstallation(json: JSON.parse("""
					{
						"regEnabled": true,
						"pushRegId": "stub",
						"isPrimary": true,
						"notificationsEnabled": true
					}
"""
		))!
		let remoteProviderMock = RemoteAPIProviderStub()
		remoteProviderMock.postInstanceClosure = { _, _ -> FetchInstanceDataResult in
			return FetchInstanceDataResult.Success(stubInstallation)
		}
		remoteProviderMock.patchInstanceClosure = { _, _, _, _ -> UpdateInstanceDataResult in
			requestSentCounter += 1
			return UpdateInstanceDataResult.Success(EmptyResponse())
		}
		mobileMessagingInstance.remoteApiProvider = remoteProviderMock

		MobileMessaging.sharedInstance?.pushServiceToken = "stub"

		MobileMessaging.sharedInstance?.installationService.syncWithServer(userInitiated: false) { err in
			tokenSynced?.fulfill() // requestSentCounter = 0

			MobileMessaging.sharedInstance?.isPushRegistrationEnabled = false
			MobileMessaging.sharedInstance?.installationService.syncWithServer(userInitiated: false) { err in
				XCTAssertEqual(requestSentCounter, 1)
				regDisabledStatusSynced?.fulfill()

				MobileMessaging.sharedInstance?.isPushRegistrationEnabled = true
				MobileMessaging.sharedInstance?.installationService.syncWithServer(userInitiated: false) { err in
					XCTAssertEqual(requestSentCounter, 2)
					regEnabledStatusSynced?.fulfill()

					MobileMessaging.sharedInstance?.isPushRegistrationEnabled = true
					MobileMessaging.sharedInstance?.installationService.syncWithServer(userInitiated: false) { err in
						XCTAssertEqual(requestSentCounter, 2)
						regEnabled2StatusSynced?.fulfill()

					}
				}
			}
		}
		self.waitForExpectations(timeout: 60) { error in
			XCTAssertEqual(requestSentCounter, 2)
		}
	}

	func testThatRegistrationEnabledStatusIsAppliedToSubservicesStatus() {
		// Message handling and Geofencing subservices must be stopped once the push reg status disabled
		// and started once push reg status enabled

		weak var registrationSynced = self.expectation(description: "registration synced")

		let stubInstallation = MMInstallation(json: JSON.parse("""
					{
						"regEnabled": false,
						"pushRegId": "stub",
						"isPrimary": true,
						"notificationsEnabled": true
					}
"""
		))!
		let remoteProviderMock = RemoteAPIProviderStub()
		remoteProviderMock.postInstanceClosure = { _, _ -> FetchInstanceDataResult in
			return FetchInstanceDataResult.Success(stubInstallation)
		}
		remoteProviderMock.patchInstanceClosure = { _, _, _, _ -> UpdateInstanceDataResult in
			return UpdateInstanceDataResult.Success(EmptyResponse())
		}


		let mm = MMTestCase.stubbedMMInstanceWithApplicationCode("stub")!.withGeofencingService()
        mm.doStart()
		MMGeofencingService.sharedInstance = GeofencingServiceStartStopMock(mmContext: mm)
		MMGeofencingService.sharedInstance!.start({ _ in })


		mm.remoteApiProvider = remoteProviderMock


		XCTAssertTrue(mm.messageHandler.isRunning)
		XCTAssertTrue(MMGeofencingService.sharedInstance!.isRunning)
		XCTAssertTrue(MobileMessaging.sharedInstance!.resolveInstallation().isPushRegistrationEnabled)

		mm.pushServiceToken = "stub"

		mm.installationService.syncWithServer(userInitiated: false) { err in
			// we got disabled status, now message handling must be stopped
			XCTAssertFalse(mm.messageHandler.isRunning)
			XCTAssertFalse(MobileMessaging.geofencingService!.isRunning)
			XCTAssertFalse(MobileMessaging.sharedInstance!.resolveInstallation().isPushRegistrationEnabled)
			registrationSynced?.fulfill()
		}
		self.waitForExpectations(timeout: 5, handler: nil)
	}

	func testThatRegistrationCleanedIfAppCodeChanged() {
        MMTestCase.startWithCorrectApplicationCode()
        
		let remoteProviderMock = RemoteAPIProviderStub()
		remoteProviderMock.postInstanceClosure = { _, _ -> FetchInstanceDataResult in
			return FetchInstanceDataResult.Success(
                MMInstallation(applicationUserId: nil, appVersion: nil, customAttributes: [:], deviceManufacturer: nil, deviceModel: nil, deviceName: nil, deviceSecure: false, deviceTimeZone: nil, geoEnabled: false, isPrimaryDevice: true, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: nil, osVersion: nil, pushRegistrationId: "new pushRegId", pushServiceToken: "someToken".data(using: String.Encoding.utf16)!.mm_toHexString, pushServiceType: nil, sdkVersion: nil)
			)
		}
		remoteProviderMock.patchInstanceClosure = { _, _, _, _ -> UpdateInstanceDataResult in
			return UpdateInstanceDataResult.Success(EmptyResponse())
		}
		mobileMessagingInstance.remoteApiProvider = remoteProviderMock

		weak var finished = self.expectation(description: "finished")
        mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken(userInitiated: false, token: "someToken".data(using: String.Encoding.utf16)!) {  error in
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

    func testThatRegistrationCleanedIfAppCodeChangedWhenAppCodePersistingDisabled() {
        MobileMessaging.privacySettings.applicationCodePersistingDisabled = true
        MMTestCase.startWithApplicationCode("oldApplicationCode")
        let token = "someToken".data(using: String.Encoding.utf16)!.mm_toHexString
        let remoteProviderMock = RemoteAPIProviderStub()
        let pushRegId = "new pushRegId"
        remoteProviderMock.postInstanceClosure = { _, _ -> FetchInstanceDataResult in
            return FetchInstanceDataResult.Success(
                MMInstallation(applicationUserId: nil, appVersion: nil, customAttributes: [:], deviceManufacturer: nil, deviceModel: nil, deviceName: nil, deviceSecure: false, deviceTimeZone: nil, geoEnabled: false, isPrimaryDevice: true, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: nil, osVersion: nil, pushRegistrationId: pushRegId, pushServiceToken: token, pushServiceType: nil, sdkVersion: nil)
            )
        }
        remoteProviderMock.patchInstanceClosure = { _, _, _, _ -> UpdateInstanceDataResult in
            return UpdateInstanceDataResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = remoteProviderMock

        weak var finished = self.expectation(description: "finished")
        mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken(userInitiated: false, token: "someToken".data(using: String.Encoding.utf16)!) {  error in
            let internalDataPersisted = NSKeyedUnarchiver.unarchiveObject(withFile: InternalData.currentPath) as! InternalData
            XCTAssertNil(internalDataPersisted.applicationCode, "application code must not be persisted")
            XCTAssertNotNil(internalDataPersisted.applicationCodeHash, "application code has must be persisted")
            XCTAssertEqual(self.mobileMessagingInstance.resolveInstallation().pushServiceToken, token)
            XCTAssertEqual(self.mobileMessagingInstance.resolveInstallation().pushRegistrationId, pushRegId)
            MobileMessaging.sharedInstance?.doStop()

            DispatchQueue.main.async {
                MMTestCase.startWithApplicationCode("newApplicationCode")
                let internalDataPersisted2 = NSKeyedUnarchiver.unarchiveObject(withFile: InternalData.currentPath) as! InternalData
                XCTAssertNil(internalDataPersisted2.applicationCode, "application code must not be persisted")
                XCTAssertNotNil(internalDataPersisted2.applicationCodeHash, "application code has must be persisted")
                XCTAssertNil(MobileMessaging.getInstallation()!.pushServiceToken, "registration must be reset after app code changes")
                XCTAssertNil(MobileMessaging.getInstallation()!.pushRegistrationId, "registration must be reset after app code changes")
                finished?.fulfill()
            }
        }

        waitForExpectations(timeout: 1000, handler: nil)
    }

	//https://openradar.appspot.com/29489461
	func testThatExpireRequestBeingSentAfterReinstallation(){
		
		MMTestCase.startWithCorrectApplicationCode()

		weak var expirationRequested = self.expectation(description: "expirationRequested")
		weak var registration2Done = self.expectation(description: "registration2Done")
		weak var registration3Done = self.expectation(description: "registration3Done")

		do {
			let remoteProviderMock = RemoteAPIProviderStub()
			remoteProviderMock.patchInstanceClosure = { _, _, _, _ -> UpdateInstanceDataResult in
				return UpdateInstanceDataResult.Success(EmptyResponse())
			}
			remoteProviderMock.postInstanceClosure = { _, _ -> FetchInstanceDataResult in
				return FetchInstanceDataResult.Success(
                    MMInstallation(applicationUserId: nil, appVersion: nil, customAttributes: [:], deviceManufacturer: nil, deviceModel: nil, deviceName: nil, deviceSecure: false, deviceTimeZone: nil, geoEnabled: false, isPrimaryDevice: true, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: nil, osVersion: nil, pushRegistrationId: "new pushRegId", pushServiceToken: "someToken".data(using: String.Encoding.utf16)!.mm_toHexString, pushServiceType: nil, sdkVersion: nil)
				)
			}
			self.mobileMessagingInstance.remoteApiProvider = remoteProviderMock
		}

        mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken(userInitiated: false, token: "someToken".data(using: String.Encoding.utf16)!) {  error in
			XCTAssertEqual(self.mobileMessagingInstance.internalData().applicationCode, MMTestConstants.kTestCorrectApplicationCode)
			XCTAssertNotNil(self.mobileMessagingInstance.resolveInstallation().pushServiceToken)
			let firstInternalId = self.mobileMessagingInstance.resolveInstallation().pushRegistrationId
			XCTAssertNotNil(firstInternalId)

			// uninstall >
            MobileMessaging.sharedInstance?.doCleanupAndStop(false)
			// < uninstall

			// reinstall >
			MMTestCase.startWithCorrectApplicationCode()
			// < reinstall

			XCTAssertEqual(self.mobileMessagingInstance.keychain.pushRegId, firstInternalId)

			do {
				let remoteProviderMock = RemoteAPIProviderStub()
				remoteProviderMock.patchInstanceClosure = { _, _, _, _ -> UpdateInstanceDataResult in
					return UpdateInstanceDataResult.Success(EmptyResponse())
				}
				remoteProviderMock.postInstanceClosure = { _, _ -> FetchInstanceDataResult in
					return FetchInstanceDataResult.Success(
                        MMInstallation(applicationUserId: nil, appVersion: nil, customAttributes: [:], deviceManufacturer: nil, deviceModel: nil, deviceName: nil, deviceSecure: false, deviceTimeZone: nil, geoEnabled:false, isPrimaryDevice: true, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: nil, osVersion: nil, pushRegistrationId: "new pushRegId2", pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil)
					)
				}
				remoteProviderMock.deleteInstanceClosure = { (_, _, expiredPushRef) -> UpdateInstanceDataResult in
					XCTAssertEqual(self.mobileMessagingInstance.keychain.pushRegId, firstInternalId)
					XCTAssertEqual(expiredPushRef, firstInternalId)
					expirationRequested?.fulfill()
					return UpdateInstanceDataResult.Success(EmptyResponse())
				}
				self.mobileMessagingInstance.remoteApiProvider = remoteProviderMock
			}

			// tries to expire after new reg created
            self.mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken(userInitiated: false, token: "someToken".data(using: String.Encoding.utf16)!) { error in
				registration2Done?.fulfill()

				XCTAssertNotEqual(self.mobileMessagingInstance.keychain.pushRegId, firstInternalId)
				XCTAssertEqual(self.mobileMessagingInstance.keychain.pushRegId, self.mobileMessagingInstance.resolveInstallation().pushRegistrationId)

				do {
					let remoteProviderMock = RemoteAPIProviderStub()
					remoteProviderMock.deleteInstanceClosure = { (_, _, _) -> UpdateInstanceDataResult in
						XCTFail("should not call expire API with no reason ")
						return UpdateInstanceDataResult.Success(EmptyResponse())
					}
					self.mobileMessagingInstance.remoteApiProvider = remoteProviderMock
				}

				// try to redundantly expire again
				self.mobileMessagingInstance.installationService.syncWithServer(userInitiated: false) { _ in
					XCTAssertEqual(self.mobileMessagingInstance.keychain.pushRegId, self.mobileMessagingInstance.resolveInstallation().pushRegistrationId)
					registration3Done?.fulfill()
				}
			}
		}

		waitForExpectations(timeout: 10, handler: nil)
	}
}

class NotificationsEnabledMock: MMApplication {
	var applicationState: UIApplication.State { return .active }
	var applicationIconBadgeNumber: Int {
		get { return 0 }
		set {}
	}
	var visibleViewController: UIViewController? { return nil }
	var isRegisteredForRemoteNotifications: Bool { return true }
	func unregisterForRemoteNotifications() {}
	func registerForRemoteNotifications() {}
	var notificationEnabled: Bool { return true }
}

class NotificationsDisabledMock: MMApplication {
	var applicationState: UIApplication.State { return .active }
	var applicationIconBadgeNumber: Int {
		get { return 0 }
		set {}
	}
	var visibleViewController: UIViewController? { return nil }
	var isRegisteredForRemoteNotifications: Bool { return true }
	func unregisterForRemoteNotifications() {}
	func registerForRemoteNotifications() {}
	var notificationEnabled: Bool { return false }
}


class GeofencingServiceStartStopMock: MMGeofencingService {
	override func suspend() {
		isRunning = false
	}
	override func start(_ completion: ((Bool) -> Void)?) {
		isRunning = true
        completion?(isRunning)
	}
	override func authorizeService(kind: MMLocationServiceKind, usage: MMLocationServiceUsage, completion: @escaping (MMGeofencingCapabilityStatus) -> Void) {
		completion(.authorized)
	}
	
	override func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {}
	
	override public class var currentCapabilityStatus: MMGeofencingCapabilityStatus {
		return MMGeofencingCapabilityStatus.authorized
	}
}
