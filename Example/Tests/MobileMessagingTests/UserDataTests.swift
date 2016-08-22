//
//  UserDataTests.swift
//  MobileMessagingExample
//
//  Created by Andrey K. on 14/07/16.
//

import XCTest
@testable import MobileMessaging

class UserDataTests: MMTestCase {
	
    func testDataPersisting() {
		let currentUser = MobileMessaging.currentUser!
		currentUser.setCustomDataForKey("nickname", object: "M")
		currentUser.externalId = "someExternalId"
		currentUser.msisdn = "123"
		currentUser.email = "some@mail.com"
		currentUser.persist()
		
		XCTAssertEqual(currentUser.customDataForKey("nickname") as? String, "M")
		XCTAssertEqual(currentUser.customData!["nickname"] as? String, "M")
		XCTAssertEqual(currentUser.externalId, "someExternalId")
		XCTAssertEqual(currentUser.msisdn, "123")
		XCTAssertEqual(currentUser.email, "some@mail.com")
		XCTAssertEqual(currentUser.predefinedDataForKey(MMUserPredefinedDataKeys.Email) as? String, "some@mail.com")
		XCTAssertEqual(currentUser.predefinedDataForKey(MMUserPredefinedDataKeys.MSISDN) as? String, "123")
		XCTAssertTrue(currentUser.predefinedData!["gender"] == nil, "custom data has nothing to do with predefined data")
		
		
		currentUser.setCustomDataForKey("nilElement", object: nil)
		
		XCTAssertEqual(currentUser.customData!["nilElement"] as? NSNull, NSNull())
		
		XCTAssertEqual(NSDate(timeIntervalSince1970: 1468593199).toJSON(), "2016-07-15")
		
		if let installation = InstallationManagedObject.MM_findFirstInContext(context: self.storage.mainThreadManagedObjectContext!) {
			
			XCTAssertTrue(installation.dirtyAttributesSet.contains(SyncableAttributesSet.externalUserId))
			XCTAssertTrue(installation.dirtyAttributesSet.contains(SyncableAttributesSet.predefinedUserData))
			XCTAssertTrue(installation.dirtyAttributesSet.contains(SyncableAttributesSet.customUserData))
			
			XCTAssertEqual(installation.customUserData!["nickname"] as? String, "M")
			XCTAssertEqual(installation.predefinedUserData![MMUserPredefinedDataKeys.MSISDN.name] as? String, "123")
			XCTAssertEqual(installation.predefinedUserData![MMUserPredefinedDataKeys.Email.name] as? String, "some@mail.com")
			XCTAssertTrue(currentUser.predefinedData!["nickname"] == nil, "custom data has nothing to do with predefined data")
			
			installation.resetDirtyAttribute(SyncableAttributesSet.customUserData)
			XCTAssertFalse(installation.dirtyAttributesSet.contains(SyncableAttributesSet.customUserData))
			
		} else {
			
			XCTFail("There must be atleast one installation object in database")
		
		}
    }
	
	func testSetupPredefinedAndCustomData() {
		let expectation = expectationWithDescription("save completed")
		cleanUpAndStop()
		startWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)
		
		//Precondiotions
		mobileMessagingInstance.currentUser?.internalId = MMTestConstants.kTestCorrectInternalID
		
		let currentUser = MobileMessaging.currentUser!
		currentUser.setCustomDataForKey("home", object: "Death Star")
		currentUser.setCustomDataForKey("drink", object: "Beer")
		currentUser.setCustomDataForKey("food", object: "Pizza")
		currentUser.setCustomDataForKey("height", object: NSNumber(double:189.5))

		currentUser.setPredefinedDataForKey(MMUserPredefinedDataKeys.FirstName, object: "Darth")
		currentUser.setPredefinedDataForKey(MMUserPredefinedDataKeys.LastName, object: "Vader")
		currentUser.setPredefinedDataForKey(MMUserPredefinedDataKeys.Birthdate, object: "1980-12-12")
		currentUser.setPredefinedDataForKey(MMUserPredefinedDataKeys.Gender, object: MMUserGenderValues.Male.name())
		currentUser.msisdn = "79214444444"
		currentUser.email = "darth@vader.com"
		
		currentUser.save { (error) in
			XCTAssertNil(error)
			
			XCTAssertEqual(currentUser.predefinedData![MMUserPredefinedDataKeys.FirstName.name] as? String, "Darth")
			XCTAssertEqual(currentUser.predefinedData![MMUserPredefinedDataKeys.LastName.name] as? String, "Vader")
			XCTAssertEqual(currentUser.predefinedData![MMUserPredefinedDataKeys.Birthdate.name] as? String, "1980-12-12")
			XCTAssertEqual(currentUser.predefinedData![MMUserPredefinedDataKeys.Gender.name] as? String, MMUserGenderValues.Male.name())
			XCTAssertEqual(currentUser.msisdn, "79214444444")
			XCTAssertEqual(currentUser.email, "darth@vader.com")
			
			XCTAssertEqual(currentUser.customData?["nativePlace"] as? String, "Tatooine")
			XCTAssertEqual(currentUser.customData?["mentor"] as? String, "Obi Wan Kenobi")
			XCTAssertEqual(currentUser.customData?["home"] as? String, "Death Star")
			XCTAssertEqual(currentUser.customData?["drink"] as? String, "Beer")
			XCTAssertEqual(currentUser.customData?["food"] as? String, "Pizza")
			XCTAssertEqual(currentUser.customData?["height"] as? NSNumber, NSNumber(double:189.5))
			expectation.fulfill()
		}
		
		waitForExpectationsWithTimeout(10, handler: nil)
	}
	
	func testDeletePredefinedAndCustomData() {
		let expectation = expectationWithDescription("data received")
		cleanUpAndStop()
		startWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)
		
		//Precondiotions
		mobileMessagingInstance.currentUser?.internalId = MMTestConstants.kTestCorrectInternalID
		
		let currentUser = MobileMessaging.currentUser!
		currentUser.msisdn = nil
		currentUser.setPredefinedDataForKey(MMUserPredefinedDataKeys.FirstName, object: nil)
		currentUser.setPredefinedDataForKey(MMUserPredefinedDataKeys.Gender, object: nil)
		currentUser.setCustomDataForKey("height", object: nil)
		
		currentUser.save { (error) in
			XCTAssertNil(error)
			
			XCTAssertEqual(currentUser.predefinedData![MMUserPredefinedDataKeys.FirstName.name] as? String, "Darth")
			XCTAssertEqual(currentUser.predefinedData![MMUserPredefinedDataKeys.LastName.name] as? String, "Vader")
			XCTAssertEqual(currentUser.predefinedData![MMUserPredefinedDataKeys.Birthdate.name] as? String, "1980-12-12")
			XCTAssertEqual(currentUser.predefinedData![MMUserPredefinedDataKeys.Gender.name] as? String, MMUserGenderValues.Male.name())
			XCTAssertNil(currentUser.msisdn)
			XCTAssertEqual(currentUser.email, "darth@vader.com")
			
			XCTAssertEqual(currentUser.customData?["nativePlace"] as? String, "Tatooine")
			XCTAssertEqual(currentUser.customData?["mentor"] as? String, "Obi Wan Kenobi")
			XCTAssertEqual(currentUser.customData?["home"] as? String, "Death Star")
			XCTAssertEqual(currentUser.customData?["drink"] as? String, "Beer")
			XCTAssertEqual(currentUser.customData?["food"] as? String, "Pizza")
			XCTAssertNil(currentUser.customData?["height"])
			expectation.fulfill()
		}
		
		waitForExpectationsWithTimeout(10, handler: nil)
	}
	
	func testGetPredefinedAndCustomData() {
		let expectation = expectationWithDescription("data received")
		cleanUpAndStop()
		startWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)
		
		//Precondiotions
		mobileMessagingInstance.currentUser?.internalId = MMTestConstants.kTestCorrectInternalID
		
		let currentUser = MobileMessaging.currentUser!
		
		currentUser.fetchFromServer { (error) in
			XCTAssertNil(error)
			
			XCTAssertEqual(currentUser.predefinedData![MMUserPredefinedDataKeys.FirstName.name] as? String, "Darth")
			XCTAssertEqual(currentUser.predefinedData![MMUserPredefinedDataKeys.LastName.name] as? String, "Vader")
			XCTAssertEqual(currentUser.predefinedData![MMUserPredefinedDataKeys.Birthdate.name] as? String, "1980-12-12")
			XCTAssertEqual(currentUser.predefinedData![MMUserPredefinedDataKeys.Gender.name] as? String, MMUserGenderValues.Male.name())
			XCTAssertEqual(currentUser.email, "darth@vader.com")
			
			XCTAssertEqual(currentUser.customData?["nativePlace"] as? String, "Tatooine")
			XCTAssertEqual(currentUser.customData?["mentor"] as? String, "Obi Wan Kenobi")
			XCTAssertEqual(currentUser.customData?["home"] as? String, "Death Star")
			XCTAssertEqual(currentUser.customData?["drink"] as? String, "Beer")
			XCTAssertEqual(currentUser.customData?["food"] as? String, "Pizza")
			expectation.fulfill()
		}
		
		waitForExpectationsWithTimeout(10, handler: nil)
	}
}