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
		let tokensexp = expectationWithDescription("device tokens saved")
		let maxCount = 2
		
        for counter in 0..<maxCount {
            let deviceToken = "token\(counter)".dataUsingEncoding(NSUTF16StringEncoding)
			mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken!) { error in
				if counter == maxCount - 1 {
					tokensexp.fulfill()
				}
			}
        }
		
		MobileMessaging.currentUser?.set(customData: "metadata1", forKey: "meta1")
        MobileMessaging.currentUser?.persist()
		
		MobileMessaging.currentUser?.set(customData: "metadata2", forKey: "meta2")
		MobileMessaging.currentUser?.persist()
		
		waitForExpectationsWithTimeout(100, handler: { err in
			let installationsNumber = InstallationManagedObject.MM_countOfEntitiesWithContext(self.storage.mainThreadManagedObjectContext!)
			
			if let installation = InstallationManagedObject.MM_findFirstInContext(context: self.storage.mainThreadManagedObjectContext!) {
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
	
        let token2Saved = expectationWithDescription("token2 saved")
		let validEmailSaved = expectationWithDescription("email saved")
		let validMsisdnSaved = expectationWithDescription("msisdn saved")
		
		mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".dataUsingEncoding(NSUTF16StringEncoding)!) {  error in
		
			self.mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken2".dataUsingEncoding(NSUTF16StringEncoding)!) {  error in
				
				token2Saved.fulfill()
				
			    dispatch_async(dispatch_get_main_queue(), {
					currentUser.save(email: MMTestConstants.kTestValidEmail, completion: { err in
						XCTAssertNil(err)
						validEmailSaved.fulfill()
					})
					
					currentUser.save(msisdn: MMTestConstants.kTestValidMSISDN, completion: { err in
						XCTAssertNil(err)
						validMsisdnSaved.fulfill()
					})
				})
			}
		}
        
        self.waitForExpectationsWithTimeout(100) { error in
			assert(MMQueue.Main.queue.isCurrentQueue)
			if let installation = InstallationManagedObject.MM_findFirstInContext(context: self.storage.mainThreadManagedObjectContext!) {
			
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
		
		let expectation = expectationWithDescription("Installation data updating")
		mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".dataUsingEncoding(NSUTF16StringEncoding)!) {  error in
			expectation.fulfill()
		}
		self.waitForExpectationsWithTimeout(100) { error in
			assert(MMQueue.Main.queue.isCurrentQueue)
			if let installation = InstallationManagedObject.MM_findFirstInContext(context: self.storage.mainThreadManagedObjectContext!) {
			
				XCTAssertTrue(installation.dirtyAttributesSet.contains(SyncableAttributesSet.deviceToken), "Dirty flag may be false only after success registration")
				XCTAssertEqual(installation.internalUserId, nil, "Internal id must be nil, server denied the application code")
				XCTAssertEqual(installation.deviceToken, "someToken".mm_toHexademicalString(), "Device token must be mocked properly. (current is \(installation.deviceToken))")
			} else {
				XCTFail("There must be atleast one installation object in database")
			}
		}
	}
	
    func testTokenNotSendsTwice() {
		var requestSentCounter = 0
		MobileMessaging.geofencingService = MMNotAvailableGeofencingServiceStub(storage: mobileMessagingInstance.storage!)
		MobileMessaging.userAgent = MMUserAgentStub()
		MobileMessaging.currentInstallation?.installationManager.registrationRemoteAPI = MMRemoteAPIMock(baseURLString: MMTestConstants.kTestBaseURLString, appCode: MMTestConstants.kTestCorrectApplicationCode, performRequestCompanionBlock: { request in
			
			switch request {
			case (is MMPostRegistrationRequest):
				
				dispatch_async(dispatch_get_main_queue(), {
					requestSentCounter += 1
				})

			default:
				break
			}
		})
		
        let expectation1 = expectationWithDescription("notification1")
        let expectation2 = expectationWithDescription("notification2")

        mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".dataUsingEncoding(NSUTF16StringEncoding)!) {  error in
            XCTAssertNil(error)
            expectation1.fulfill()
            self.mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".dataUsingEncoding(NSUTF16StringEncoding)!) {  error in
                XCTAssertNil(error)
                expectation2.fulfill()
            }
        }
        
        self.waitForExpectationsWithTimeout(100) { error in
			dispatch_async(dispatch_get_main_queue(), {
				XCTAssertEqual(requestSentCounter, 1)
			})
        }
    }
	
    func testRegistrationDataNotSendsWithoutToken() {
        let sync1 = expectationWithDescription("sync1")
        MobileMessaging.currentInstallation?.syncWithServer({ (error) -> Void in
            XCTAssertNotNil(error)
            sync1.fulfill()
        })
        
        self.waitForExpectationsWithTimeout(100) { error in
        }
    }
}
