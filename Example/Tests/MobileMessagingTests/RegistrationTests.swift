//
//  RegistrationTests.swift
//  RegistrationTests
//
//  Created by Andrey K. on 17/02/16.
//

import XCTest
@testable import MobileMessaging


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
			
			if let installation = InstallationManagedObject.MM_findFirstInContext(self.storage.mainThreadManagedObjectContext!) {
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
			if let installation = InstallationManagedObject.MM_findFirstInContext(self.storage.mainThreadManagedObjectContext!) {
			
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
			if let installation = InstallationManagedObject.MM_findFirstInContext(self.storage.mainThreadManagedObjectContext!) {
			
				XCTAssertTrue(installation.dirtyAttributesSet.contains(SyncableAttributesSet.deviceToken), "Dirty flag may be false only after success registration")
				XCTAssertEqual(installation.internalUserId, nil, "Internal id must be nil, server denied the application code")
				XCTAssertEqual(installation.deviceToken, "someToken".mm_toHexademicalString(), "Device token must be mocked properly. (current is \(installation.deviceToken))")
			} else {
				XCTFail("There must be atleast one installation object in database")
			}
		}
	}
	

	var requestSentCounter = 0
    func testTokenNotSendsTwice() {
		MobileMessaging.userAgent = UserAgentStub()
		
		MobileMessaging.currentInstallation?.installationManager.registrationRemoteAPI = MMRemoteAPIMock(baseURLString: MMTestConstants.kTestBaseURLString, appCode: MMTestConstants.kTestCorrectApplicationCode, performRequestCompanionBlock: { request in
			
			switch request {
			case (is MMPostRegistrationRequest):
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
		
        self.waitForExpectations(timeout:100) { error in
			DispatchQueue.main.async {
				XCTAssertEqual(self.requestSentCounter, 1)
			}
        }
    }
	
    func testRegistrationDataNotSendsWithoutToken() {
        weak var sync1 = expectation(description: "sync1")
		
		if MobileMessaging.currentInstallation == nil {
			XCTFail("Installation is nil")
			sync1?.fulfill()
		}
		
        MobileMessaging.currentInstallation?.syncWithServer(completion: { (error) -> Void in
            XCTAssertNotNil(error)
            sync1?.fulfill()
        })
		
        self.waitForExpectations(timeout: 60, handler: nil)
    }
}
