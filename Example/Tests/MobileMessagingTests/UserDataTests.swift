//
//  UserDataTests.swift
//  MobileMessagingExample
//
//  Created by Andrey K. on 14/07/16.
//

import XCTest
@testable import MobileMessaging

var darthVaderDateOfDeath: NSDate {
	let comps = NSDateComponents()
	comps.year = 1983
	comps.month = 5
	comps.day = 25
	comps.hour = 0
	comps.minute = 0
	comps.second = 0
	comps.timeZone = NSTimeZone(forSecondsFromGMT: 0) // has expected timezone
	comps.calendar = NSCalendar(identifier: NSCalendarIdentifierGregorian)
	return comps.date!
}


class UserDataTests: MMTestCase {
	
	func testCustomUserDataPayloadConstructors() {
		
		//date
		do {
			let comps = NSDateComponents()
			comps.year = 2016
			comps.month = 12
			comps.day = 31
			comps.hour = 23
			comps.minute = 55
			comps.second = 00
			comps.timeZone = NSTimeZone(forSecondsFromGMT: 3*60*60) // has expected timezone
			comps.calendar = NSCalendar(identifier: NSCalendarIdentifierGregorian)
			let date = comps.date!
			let request = MMPostUserDataRequest(internalUserId: "any", externalUserId: "any", predefinedUserData: ["name": "JohnDow"], customUserData: ["registrationDate": date])
			
			let expectedDict: NSDictionary = [
				MMAPIKeys.kUserDataPredefinedUserData: [
					"name": "JohnDow"
				],
				MMAPIKeys.kUserDataCustomUserData: [
					"registrationDate" : [
						"type": "Date",
						"value": "2016-12-31T23:55:00+03:00"
					]
				]
			]
			XCTAssertTrue((request.body! as NSDictionary).isEqual(expectedDict))
		}
		
		// number
		do {
			let request = MMPostUserDataRequest(internalUserId: "any", externalUserId: "any", predefinedUserData: ["name": "JohnDow"], customUserData: ["bootsize": 9.5])
			let expectedDict: NSDictionary = [
				MMAPIKeys.kUserDataPredefinedUserData: [
					"name": "JohnDow"
				],
				MMAPIKeys.kUserDataCustomUserData: [
					"bootsize" : [
						"type": "Number",
						"value": 9.5
					]
				]
			]
			XCTAssertTrue((request.body! as NSDictionary).isEqual(expectedDict))
		}
		
		// null
		do {
			let request = MMPostUserDataRequest(internalUserId: "any", externalUserId: "any", predefinedUserData: ["name": "JohnDow"], customUserData: ["registrationDate": NSNull()])
			let expectedDict = [
				MMAPIKeys.kUserDataPredefinedUserData: [
					"name": "JohnDow"
				],
				MMAPIKeys.kUserDataCustomUserData: [
					"registrationDate" : NSNull()
				]
			]
			XCTAssertTrue((request.body! as NSDictionary).isEqual(expectedDict))
		}
	}
	
	func testDataPersisting() {
		let currentUser = MobileMessaging.currentUser!
		currentUser.set(customData: "M", forKey: "nickname")
		currentUser.externalId = "someExternalId"
		currentUser.msisdn = "123"
		currentUser.email = "some@mail.com"
		currentUser.persist()
		
		XCTAssertEqual(currentUser.customData(forKey: "nickname") as? String, "M")
		XCTAssertEqual(currentUser.customData!["nickname"] as? String, "M")
		XCTAssertEqual(currentUser.externalId, "someExternalId")
		XCTAssertEqual(currentUser.msisdn, "123")
		XCTAssertEqual(currentUser.email, "some@mail.com")
		XCTAssertEqual(currentUser.predefinedData(forKey: MMUserPredefinedDataKeys.Email) as? String, "some@mail.com")
		XCTAssertEqual(currentUser.predefinedData(forKey: MMUserPredefinedDataKeys.MSISDN) as? String, "123")
		XCTAssertTrue(currentUser.predefinedData!["gender"] == nil, "custom data has nothing to do with predefined data")
		
		
		currentUser.set(customData: nil, forKey: "nilElement")
		
		XCTAssertTrue(currentUser.customData!["nilElement"] is NSNull)
		
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
		weak var expectation = expectationWithDescription("save completed")
		cleanUpAndStop()
		startWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)
		
		//Precondiotions
		mobileMessagingInstance.currentUser?.internalId = MMTestConstants.kTestCorrectInternalID
		
		let currentUser = MobileMessaging.currentUser!
		currentUser.set(customData: "Death Star", forKey: "home")
		currentUser.set(customData: "Beer", forKey: "drink")
		currentUser.set(customData: "Pizza", forKey: "food")
		currentUser.set(customData: 189.5, forKey: "height")
		
		currentUser.set(predefinedData: "Darth", forKey: MMUserPredefinedDataKeys.FirstName)
		currentUser.set(predefinedData: "Vader", forKey: MMUserPredefinedDataKeys.LastName)
		currentUser.set(predefinedData: "1980-12-12", forKey: MMUserPredefinedDataKeys.Birthdate)
		currentUser.set(predefinedData: MMUserGenderValues.Male.name(), forKey: MMUserPredefinedDataKeys.Gender)
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
			XCTAssertEqual(currentUser.customData?["dateOfDeath"] as? NSDate, darthVaderDateOfDeath)
			expectation?.fulfill()
		}
		
		waitForExpectationsWithTimeout(10, handler: nil)
	}
	
	func testDeletePredefinedAndCustomData() {
		weak var expectation = expectationWithDescription("data received")
		cleanUpAndStop()
		startWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)
		
		//Precondiotions
		mobileMessagingInstance.currentUser?.internalId = MMTestConstants.kTestCorrectInternalID
		
		let currentUser = MobileMessaging.currentUser!
		currentUser.msisdn = nil
		currentUser.set(predefinedData: nil, forKey: MMUserPredefinedDataKeys.FirstName)
		currentUser.set(predefinedData: nil, forKey: MMUserPredefinedDataKeys.Gender)
		currentUser.set(customData: nil, forKey: "height")
		
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
			XCTAssertEqual(currentUser.customData?["dateOfDeath"] as? NSDate, darthVaderDateOfDeath)
			XCTAssertNil(currentUser.customData?["height"])
			expectation?.fulfill()
		}
		
		waitForExpectationsWithTimeout(10, handler: nil)
	}
	
	func testGetPredefinedAndCustomData() {
		weak var expectation = expectationWithDescription("data received")
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
			XCTAssertEqual(currentUser.customData?["dateOfDeath"] as? NSDate, darthVaderDateOfDeath)
			expectation?.fulfill()
		}
		
		waitForExpectationsWithTimeout(10, handler: nil)
	}
	
	func testSetPredefinedData() {
		MobileMessaging.currentInstallation?.installationManager.setValueForKey("predefinedUserData", value:
			[
				MMUserPredefinedDataKeys.LastName.name: "Darth",
				MMUserPredefinedDataKeys.Gender.name: "F",
				MMUserPredefinedDataKeys.Telephone.name: "89999999999"
			]
		)
		
		let currentUser = MobileMessaging.currentUser!
		
		currentUser.predefinedData = [
			MMUserPredefinedDataKeys.LastName.name: "SkyWorker",
			MMUserPredefinedDataKeys.Gender.name: "M",
		]
		
		XCTAssertEqual(currentUser.predefinedData?.count, 2)
		XCTAssertEqual(currentUser.predefinedData?[MMUserPredefinedDataKeys.LastName.name] as? String, "SkyWorker")
		XCTAssertEqual(currentUser.predefinedData?[MMUserPredefinedDataKeys.Gender.name] as? String, "M")
		
		currentUser.predefinedData = [
			MMUserPredefinedDataKeys.FirstName.name: "Luk",
			MMUserPredefinedDataKeys.Email.name: "sky@worker.com",
		]
		
		XCTAssertEqual(currentUser.predefinedData?.count, 2)
		XCTAssertEqual(currentUser.predefinedData?[MMUserPredefinedDataKeys.FirstName.name] as? String, "Luk")
		XCTAssertEqual(currentUser.predefinedData?[MMUserPredefinedDataKeys.Email.name] as? String, "sky@worker.com")
	}
}