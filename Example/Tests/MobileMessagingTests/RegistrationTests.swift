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
		let tokensexp = expectation(description: "device tokens saved")
		let maxCount = 2
		
        for counter in 0..<maxCount {
            let deviceToken = "token\(counter)".data(using: String.Encoding.utf16)
			mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken!) { error in
				if counter == maxCount - 1 {
					tokensexp.fulfill()
				}
			}
        }
		
		MobileMessaging.currentUser?.set(customData: "metadata1" as NSString, forKey: "meta1")
        MobileMessaging.currentUser?.persist()
		MobileMessaging.currentUser?.set(customData: "metadata2" as NSString, forKey: "meta2")
		MobileMessaging.currentUser?.persist()
		
		waitForExpectations(timeout: 100, handler: { err in
			let installationsNumber = InstallationManagedObject.MM_countOfEntitiesWithContext(self.storage.mainThreadManagedObjectContext!)
			
			if let installation = InstallationManagedObject.MM_findFirstInContext(self.storage.mainThreadManagedObjectContext!) {
				XCTAssertEqual(installationsNumber, 1, "there must be one installation object persisted")
				XCTAssertEqual(installation.deviceToken, "token\(maxCount-1)".mm_toHexademicalString(), "Most recent token must be persisted")
				XCTAssertEqual((installation.customUserData as! [String: String])["meta2"], "metadata2", "meta2 key must contain metadata2")
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
		
        let token2Saved = expectation(description: "token2 saved")
		let validEmailSaved = expectation(description: "email saved")
		let validMsisdnSaved = expectation(description: "msisdn saved")
		
		mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".data(using: String.Encoding.utf16)!) {  error in
		
			self.mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken2".data(using: String.Encoding.utf16)!) {  error in
				
				token2Saved.fulfill()
				
				currentUser.email = MMTestConstants.kTestValidEmail
				currentUser.msisdn = MMTestConstants.kTestValidMSISDN
				
				currentUser.save { err in
					XCTAssertNil(err)
					validEmailSaved.fulfill()
					validMsisdnSaved.fulfill()
				}
			}
		}
        
        self.waitForExpectations(timeout: 100) { error in
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
		
		let expectation = self.expectation(description: "Installation data updating")
		mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".data(using: String.Encoding.utf16)!) {  error in
			expectation.fulfill()
		}
		self.waitForExpectations(timeout: 100) { error in
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
		
        let expectation1 = expectation(description: "notification1")
        let expectation2 = expectation(description: "notification2")

        mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".data(using: String.Encoding.utf16)!) {  error in
            XCTAssertNil(error)
            expectation1.fulfill()

            self.mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".data(using: String.Encoding.utf16)!) {  error in
                XCTAssertNil(error)
                expectation2.fulfill()
            }
        }
		
        self.waitForExpectations(timeout:100) { error in
			DispatchQueue.main.async {
				XCTAssertEqual(self.requestSentCounter, 1)
			}
        }
    }
	
    func testRegistrationDataNotSendsWithoutToken() {
        let sync1 = expectation(description: "sync1")
        MobileMessaging.currentInstallation?.syncWithServer(completion: { (error) -> Void in
            XCTAssertNotNil(error)
            sync1.fulfill()
        })
		
        self.waitForExpectations(timeout: 100) { error in
        }
    }
}
