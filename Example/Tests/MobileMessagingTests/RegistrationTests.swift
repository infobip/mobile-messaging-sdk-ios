//
//  RegistrationTests.swift
//  RegistrationTests
//
//  Created by Andrey K. on 17/02/16.
//

import XCTest
@testable import MobileMessaging

final class InstallationMock: NSObject {
    var deviceToken: String?
	var internalId: String?
    var metaData: NSDictionary?
    
    init(deviceToken: String?, metaData: NSDictionary?) {
        self.deviceToken = deviceToken
        self.metaData = metaData
    }
}

final class RegistrationTests: MMTestCase {
    
    func testInstallationPersisting() {
		let metaexp = expectationWithDescription("meta2 saved")
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
		
        MobileMessaging.currentInstallation?.setMetaForKey("meta1", object: "metadata1")
        MobileMessaging.currentInstallation?.save()
		
        MobileMessaging.currentInstallation?.setMetaForKey("meta2", object: "metadata2")
		MobileMessaging.currentInstallation?.save {
			metaexp.fulfill()
		}
		
		waitForExpectationsWithTimeout(100, handler: { err in
			let installationsNumber = InstallationManagedObject.MM_countOfEntitiesWithContext(self.storage.mainThreadManagedObjectContext!)
			
			if let installation = InstallationManagedObject.MM_findFirstInContext(self.storage.mainThreadManagedObjectContext!) {
				XCTAssertEqual(installationsNumber, 1, "there must be one installation object persisted")
				XCTAssertEqual(installation.deviceToken, "token\(maxCount-1)".toHexademicalString(), "Most recent token must be persisted")
				XCTAssertEqual((installation.metaData as! [String: String])["meta2"], "metadata2", "meta2 key must contain metadata2")
				XCTAssertFalse(installation.dirtyAttributesSet.contains(SyncableAttributes.deviceToken), "Device token must be synced with server")
			} else {
				XCTFail("There must be atleast one installation object in database")
			}
		})
    }

    func testRegisterForRemoteNotificationsWithDeviceToken() {
		guard let currentInstallation = MobileMessaging.currentInstallation else {
			XCTFail("Installation not initialized")
			return
		}
		
        let token2Saved = expectationWithDescription("token2 saved")
		let validEmailSaved = expectationWithDescription("email saved")
		let validMsisdnSaved = expectationWithDescription("msisdn saved")
		let invalidEmailSaved = expectationWithDescription("email saved")
		let invalidMsisdnSaved = expectationWithDescription("msisdn saved")
		
		mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".dataUsingEncoding(NSUTF16StringEncoding)!) {  error in
		
			self.mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken2".dataUsingEncoding(NSUTF16StringEncoding)!) {  error in
				
				token2Saved.fulfill()
				
				currentInstallation.saveEmail(MMTestConstants.kTestValidEmail, completion: { err in
					XCTAssertNil(err)
					validEmailSaved.fulfill()
				})
				
				currentInstallation.saveMSISDN(MMTestConstants.kTestValidMSISDN, completion: { err in
					XCTAssertNil(err)
					validMsisdnSaved.fulfill()
				})
				
				currentInstallation.saveEmail(MMTestConstants.kTestInvalidEmail, completion: { err in
					XCTAssertNotNil(err)
					invalidEmailSaved.fulfill()
				})
				
				currentInstallation.saveMSISDN(MMTestConstants.kTestInvalidMSISDN, completion: { err in
					XCTAssertNotNil(err)
					invalidMsisdnSaved.fulfill()
				})
			}
		}
        
        self.waitForExpectationsWithTimeout(100) { error in
			assert(MMQueue.Main.queue.isCurrentQueue)
			if let installation = InstallationManagedObject.MM_findFirstInContext(self.storage.mainThreadManagedObjectContext!) {
			
				XCTAssertFalse(installation.dirtyAttributesSet.contains(SyncableAttributes.deviceToken), "current installation must be synchronized")
				XCTAssertEqual(installation.internalId, MMTestConstants.kTestCorrectInternalID, "internal id must be mocked properly. (current is \(installation.internalId))")
				XCTAssertEqual(installation.deviceToken, "someToken2".toHexademicalString(), "Device token must be mocked properly. (current is \(installation.deviceToken))")
				XCTAssertEqual(installation.email, MMTestConstants.kTestValidEmail, "")
				XCTAssertEqual(installation.msisdn, MMTestConstants.kTestValidMSISDN, "")
				
				XCTAssertFalse(installation.dirtyAttributesSet.contains(SyncableAttributes.deviceToken), "")
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
			if let installation = InstallationManagedObject.MM_findFirstInContext(self.storage.mainThreadManagedObjectContext!) {
			
				XCTAssertTrue(installation.dirtyAttributesSet.contains(SyncableAttributes.deviceToken), "Dirty flag may be false only after success registration")
				XCTAssertEqual(installation.internalId, nil, "Internal id must be nil, server denied the application code")
				XCTAssertEqual(installation.deviceToken, "someToken".toHexademicalString(), "Device token must be mocked properly. (current is \(installation.deviceToken))")
			} else {
				XCTFail("There must be atleast one installation object in database")
			}
		}
	}
    
    func testTokenNotSendsTwice() {
        let expectation1 = expectationWithDescription("notification1")
        let expectation2 = expectationWithDescription("notification2")

        mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".dataUsingEncoding(NSUTF16StringEncoding)!) {  error in
            XCTAssertNil(error)
            expectation1.fulfill()
            self.mobileMessagingInstance.didRegisterForRemoteNotificationsWithDeviceToken("someToken".dataUsingEncoding(NSUTF16StringEncoding)!) {  error in
                XCTAssertNotNil(error)
                expectation2.fulfill()
            }
        }
        
        self.waitForExpectationsWithTimeout(100) { error in
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
    
    func testRegistrationDataNotSendsTwice() {
		
        mobileMessagingInstance.currentInstallation?.internalId = MMTestConstants.kTestCorrectInternalID
		mobileMessagingInstance.currentInstallation?.deviceToken = "someToken"
		
        let sync1 = expectationWithDescription("sync1")
        let sync2 = expectationWithDescription("sync2")
		
        mobileMessagingInstance.currentInstallation?.syncWithServer({ (error) -> Void in
            XCTAssertNil(error)
            sync1.fulfill()
            self.mobileMessagingInstance.currentInstallation?.syncWithServer({ (error) -> Void in
                XCTAssertNotNil(error)
                sync2.fulfill()
            })
        })
        
        self.waitForExpectationsWithTimeout(100) { error in
        }
    }
}
