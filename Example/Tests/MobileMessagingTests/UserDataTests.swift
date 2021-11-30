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
        MMTestCase.startWithCorrectApplicationCode()
        
		weak var expectation = self.expectation(description: "done")
		
		let u = MobileMessaging.getUser()!
		u.customAttributes = ["nickname": "Crusher" as NSString, "nilElement": NSNull()]
		u.externalUserId = "someExternalId"
		u.phones = ["123"]
		u.emails = ["some@mail.com"]
		u.birthday = darthVaderDateOfBirth
		
		MobileMessaging.saveUser(u) { (error) in
			// Assert delta content
			
			let u = MobileMessaging.getUser()!
			
			XCTAssertEqual(u.customAttributes?["nickname"] as? String, "Crusher")
			XCTAssertEqual(u.customAttributes?["nilElement"] as? NSNull, NSNull())
			XCTAssertEqual(u.phones, ["123"])
			XCTAssertEqual(u.birthday, darthVaderDateOfBirth)
			XCTAssertEqual(u.emails, ["some@mail.com"])
			
			expectation?.fulfill()
		}
		waitForExpectations(timeout: 20, handler: nil)
	}
	
	func testJsonDecoding() {
        MMTestCase.startWithCorrectApplicationCode()
        
		weak var expectation = self.expectation(description: "data fetched")
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		
		let currentUser = MobileMessaging.getUser()!
		
		let jsonStr = """
	{
		"phones": [
			{
				"number": "1",
				"preferred": true
			},
			{
				"number": "2",
				"preferred": false
			}
		],
		"emails": [
			{
				"address": "1xxx@xxx.com",
				"preferred": true
			},
			{
				"address": "2xxx@xxx.com",
				"preferred": false
			}
		],
		"customAttributes": {
			"nativePlace": "Tatooine",
			"height": 189.5,
			"dateOfDeath": "1983-05-25",
			"car": null,
			"purchases": [
				{"item": "laptop", "price": 1000.50, "date": "2020-01-15", "preOwned": true},
				{"item": "phone", "price": 500.10, "date": "2019-01-15", "preOwned": false}
			]
		},
		"instances": [
			{
				"pushRegId": "pushregid1",
				"isPrimary": true,
				"regEnabled": true,
				"deviceManufacturer": "Apple",
				"deviceModel": "iPhone 1",
				"deviceName": "Johns iPhone",
				"notificationsEnabled": true,
				"os": "iOS"
			},
			{
				"pushRegId": "pushregid2",
				"isPrimary": false,
				"regEnabled": false,
				"deviceManufacturer": "Samsung",
				"deviceModel": "Galaxy",
				"deviceName": "Johns Sam",
				"notificationsEnabled": true,
				"os": "Android"
			}
		]
	}
"""
		let json = JSON.parse(jsonStr)
		let remoteApiProvider = RemoteAPIProviderStub()
		remoteApiProvider.getUserClosure = { (_, _) -> FetchUserDataResult in
			return FetchUserDataResult.Success(MMUser(json: json)!)
		}
		mobileMessagingInstance.remoteApiProvider = remoteApiProvider
		
		mobileMessagingInstance.userService.fetchFromServer(userInitiated: true, completion: { (user, error) in
			XCTAssertNil(error)
			
			XCTAssertNil(currentUser.customAttributes?["car"])
			
			let primaryInstallation = (user.installations?.first(where: {$0.isPrimaryDevice}))!
			XCTAssertEqual(primaryInstallation.deviceModel, "iPhone 1")
			XCTAssertEqual(primaryInstallation.deviceManufacturer, "Apple")
			XCTAssertEqual(primaryInstallation.pushRegistrationId, "pushregid1")
			XCTAssertEqual(primaryInstallation.deviceName, "Johns iPhone")
			XCTAssertEqual(primaryInstallation,
						   MMInstallation(applicationUserId: nil, appVersion: nil, customAttributes: [:], deviceManufacturer: "Apple", deviceModel: "iPhone 1", deviceName: "Johns iPhone", deviceSecure: false, deviceTimeZone: nil, geoEnabled: false, isPrimaryDevice: true, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: "iOS", osVersion: nil, pushRegistrationId: "pushregid1", pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil)
			)
			
			let secondaryInstallation = (user.installations?.first(where: {!$0.isPrimaryDevice}))!
			XCTAssertEqual(secondaryInstallation.deviceModel, "Galaxy")
			XCTAssertEqual(secondaryInstallation.deviceManufacturer, "Samsung")
			XCTAssertEqual(secondaryInstallation.pushRegistrationId, "pushregid2")
			XCTAssertEqual(secondaryInstallation.deviceName, "Johns Sam")
			XCTAssertEqual(secondaryInstallation,
						   MMInstallation(applicationUserId: nil, appVersion: nil, customAttributes: [:], deviceManufacturer: "Samsung", deviceModel: "Galaxy", deviceName: "Johns Sam", deviceSecure: false, deviceTimeZone: nil, geoEnabled: false, isPrimaryDevice: false, isPushRegistrationEnabled: false, language: nil, notificationsEnabled: true, os: "Android", osVersion: nil, pushRegistrationId: "pushregid2", pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil)
			)
			
			XCTAssertTrue(user.phones?.contains("1") ?? false)
			XCTAssertTrue(user.phones?.contains("2") ?? false)
			
			XCTAssertTrue(user.emails?.contains("1xxx@xxx.com") ?? false)
			XCTAssertTrue(user.emails?.contains("2xxx@xxx.com") ?? false)
			
			XCTAssertEqual(user.customAttributes?["nativePlace"] as? String, "Tatooine")
			XCTAssertEqual(user.customAttributes?["height"] as? NSNumber, 189.5)
			XCTAssertEqual(user.customAttributes?["dateOfDeath"] as? NSDate, darthVaderDateOfDeath)
			
			let customAtts = user.customAttributes!
			XCTAssertNil(customAtts["car"])
			XCTAssertEqual(customAtts["nativePlace"] as? String, "Tatooine")
			XCTAssertEqual(customAtts["height"] as? NSNumber, 189.5)
			XCTAssertEqual(customAtts["dateOfDeath"] as? NSDate, darthVaderDateOfDeath)
			XCTAssertEqual(customAtts["purchases"] as? NSArray, [
				["item": "laptop", "price": NSNumber(value:1000.50), "date": "2020-01-15", "preOwned": true],
				["item": "phone", "price": NSNumber(value:500.10), "date": "2019-01-15", "preOwned": false]
			])
			expectation?.fulfill()
		})
		
		waitForExpectations(timeout: 20, handler: nil)
	}
	
	func testUserDataFetching() {
        MMTestCase.startWithCorrectApplicationCode()
        
		weak var expectation = self.expectation(description: "save completed")
		
		//Precondiotions
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		
		let remoteApiProvider = RemoteAPIProviderStub()
		remoteApiProvider.getUserClosure = { _, _ -> FetchUserDataResult in
			let response = MMUser(externalUserId: nil, firstName: "Darth", middleName: nil, lastName: "Vader", phones: ["79214444444"], emails: ["darth@vader.com"], tags: nil, gender: .Male, birthday: DateStaticFormatters.ContactsServiceDateFormatter.date(from: "1980-12-12"), customAttributes: ["home": "Death Star" as NSString, "drink": "Beer" as NSString, "food": "Pizza" as NSString, "height": 189.5 as NSNumber, "nativePlace": "Tatooine" as NSString, "mentor": "Obi Wan Kenobi" as NSString, "dateOfDeath": darthVaderDateOfDeath as NSDate], installations: [MMInstallation(applicationUserId: nil, appVersion: nil, customAttributes: [:], deviceManufacturer: nil, deviceModel: nil, deviceName: nil, deviceSecure: true, deviceTimeZone: nil, geoEnabled: true, isPrimaryDevice: true, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: "iOS", osVersion: nil, pushRegistrationId: "pushRegId1", pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil)])
			
			return FetchUserDataResult.Success(response)
		}
		mobileMessagingInstance.remoteApiProvider = remoteApiProvider
		// explicitly reset dirty attributes to accomplish the successful fetching
		
		MobileMessaging.fetchUser(completion: { (user, error) in
			XCTAssertNil(error)
			let currentUser = MobileMessaging.getUser()!
			
			XCTAssertNil(currentUser.externalUserId)
			
			XCTAssertEqual(currentUser.firstName, "Darth")
			XCTAssertEqual(currentUser.lastName, "Vader")
			XCTAssertEqual(currentUser.birthday, darthVaderDateOfBirth)
			XCTAssertEqual(currentUser.gender, .Male)
			XCTAssertEqual(currentUser.phones, ["79214444444"])
			XCTAssertEqual(currentUser.emails?.first, "darth@vader.com")
			XCTAssertEqual(currentUser.installations, [MMInstallation(applicationUserId: nil, appVersion: nil, customAttributes: [:], deviceManufacturer: nil, deviceModel: nil, deviceName: nil, deviceSecure: true, deviceTimeZone: nil, geoEnabled: true, isPrimaryDevice: true, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: "iOS", osVersion: nil, pushRegistrationId: "pushRegId1", pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil)])
			
			XCTAssertEqual(currentUser.customAttributes?["nativePlace"] as? String, "Tatooine")
			XCTAssertEqual(currentUser.customAttributes?["mentor"] as? String, "Obi Wan Kenobi")
			XCTAssertEqual(currentUser.customAttributes?["home"] as? String, "Death Star")
			XCTAssertEqual(currentUser.customAttributes?["drink"] as? String, "Beer")
			XCTAssertEqual(currentUser.customAttributes?["food"] as? String, "Pizza")
			XCTAssertEqual(currentUser.customAttributes?["height"] as? NSNumber, 189.5)
			XCTAssertEqual(currentUser.customAttributes?["dateOfDeath"] as? NSDate, darthVaderDateOfDeath)
			expectation?.fulfill()
		})
		
		waitForExpectations(timeout: 20, handler: nil)
	}
	
	func testThatFetchedUserDataIgnoredIfHasUnsyncedLocalChanges() {
		MMTestCase.startWithCorrectApplicationCode()
        
		weak var expectation = self.expectation(description: "data received")
		weak var expectationAPICallPerformed = self.expectation(description: "expectationAPICallPerformed")
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		
		let remoteApiProvider = RemoteAPIProviderStub()
		remoteApiProvider.getUserClosure = { _, _ -> FetchUserDataResult in
			expectationAPICallPerformed?.fulfill()
			let response = MMUser(externalUserId: nil, firstName: "Darth", middleName: nil, lastName: "Vader", phones: ["79214444444"], emails: ["darth@vader.com"], tags: nil, gender: .Male, birthday: DateStaticFormatters.ContactsServiceDateFormatter.date(from: "1980-12-12"), customAttributes: ["home": "Death Star" as NSString, "drink": "Beer" as NSString, "food": "Pizza" as NSString, "height": 189.5 as NSNumber, "nativePlace": "Tatooine" as NSString, "mentor": "Obi Wan Kenobi" as NSString, "dateOfDeath": darthVaderDateOfDeath as NSDate], installations: nil)
			return FetchUserDataResult.Success(response)
		}
		mobileMessagingInstance.remoteApiProvider = remoteApiProvider
		
		let user = MobileMessaging.getUser()!
		user.firstName = "John" // unsynced local change
		user.archiveDirty()
		
		mobileMessagingInstance.userService.fetchFromServer(userInitiated: true) { (_, _) in
			expectation?.fulfill()
		}
		
		waitForExpectations(timeout: 20, handler: { _ in
			XCTAssertEqual(user.firstName, "John") // must be preserved
		})
	}
	
	func testTagsConvertedToArray() {
        MMTestCase.startWithCorrectApplicationCode()
		mobileMessagingInstance.pushRegistrationId = "123"
		
		let currentUser = MobileMessaging.getUser()!
		currentUser.tags = Set(["t1"])
		
		let b = UserDataMapper.requestPayload(currentUser: mobileMessagingInstance.currentUser(), dirtyUser: currentUser)
        waitForExpectations(timeout: 5) { _ in
            XCTAssertTrue(b!["tags"] is [String])
        }
		
	}
	
	func testThatUserDataIsNotPersistedIfPrivacySettingsSpecified() {
        MMTestCase.startWithCorrectApplicationCode()
        
		MobileMessaging.privacySettings.userDataPersistingDisabled = true
		mobileMessagingInstance.pushRegistrationId = "123"
		
		let currentUser = MobileMessaging.getUser()!
		currentUser.lastName = "Skywalker"
		currentUser.gender = .Male
		currentUser.emails = ["luke@starwars.com"]
		currentUser.phones = ["123"]
		currentUser.externalUserId = "123"
		currentUser.customAttributes = ["home": "Death Star" as NSString]
		currentUser.archiveAll()
		
		do {
			let dirtyUser = NSKeyedUnarchiver.unarchiveObject(withFile: MMUser.dirtyPath) as! MMUser
			// we havent stored on disk
			XCTAssertNil(dirtyUser.phones, "userdata must not be persisted")
			XCTAssertNil(dirtyUser.lastName, "userdata must not be persisted")
			XCTAssertNil(dirtyUser.gender, "userdata must not be persisted")
			XCTAssertNil(dirtyUser.emails, "userdata must not be persisted")
			XCTAssertNil(dirtyUser.customAttributes, "userdata must not be persisted")
			XCTAssertNil(dirtyUser.externalUserId, "userdata must not be persisted")
			
			let currentUser = NSKeyedUnarchiver.unarchiveObject(withFile: MMUser.currentPath) as! MMUser
			// we havent stored on disk
			XCTAssertNil(currentUser.phones, "userdata must not be persisted")
			XCTAssertNil(currentUser.lastName, "userdata must not be persisted")
			XCTAssertNil(currentUser.gender, "userdata must not be persisted")
			XCTAssertNil(currentUser.emails, "userdata must not be persisted")
			XCTAssertNil(currentUser.customAttributes, "userdata must not be persisted")
			XCTAssertNil(currentUser.externalUserId, "userdata must not be persisted")
		}
		
		// but we still able to get data from memory
		let inMemoryUser = MobileMessaging.getUser()!
		XCTAssertEqual(inMemoryUser.emails, ["luke@starwars.com"])
		XCTAssertEqual(inMemoryUser.phones, ["123"])
		XCTAssertEqual(inMemoryUser.externalUserId, "123")
		XCTAssertEqual(inMemoryUser.lastName, "Skywalker")
		XCTAssertEqual(inMemoryUser.gender, .Male)
		XCTAssertEqual(inMemoryUser.customAttributes?["home"] as? NSString, "Death Star")
        
        waitForExpectations(timeout: 20, handler: nil)
	}
	
	//TODO:
	// test that error parses to a UpdateUserDataResult.Failure(NSError(domain: x, code: x, userInfo: [Consts.APIKeys.errorMessageId : "USER_MERGE_INTERRUPTED"]))
	
	func testThatUnwantedMergeErrorIsPorpagated() {
        MMTestCase.startWithCorrectApplicationCode()
        
		weak var expectation = self.expectation(description: "data fetched")
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		
		let jsonStr = """
		{
			"requestError": {
				"serviceException" : {
					"messageId" : "USER_MERGE_INTERRUPTED",
					"text" : "something"
				}
			}
		}
	"""
		let requestError = MMRequestError(json: JSON.parse(jsonStr))
		let remoteApiProvider = RemoteAPIProviderStub()
		remoteApiProvider.patchUserClosure = { (_, _, _) -> UpdateUserDataResult in
			return UpdateUserDataResult.Failure(requestError?.foundationError)
		}
		mobileMessagingInstance.remoteApiProvider = remoteApiProvider
		
		let user = MobileMessaging.getUser()!
		user.firstName = "john"
		MobileMessaging.saveUser(user) { (error) in
			XCTAssertNotNil(error)
			XCTAssertEqual(error?.mm_code, "USER_MERGE_INTERRUPTED")
			expectation?.fulfill()
		}
		waitForExpectations(timeout: 20, handler: nil)
	}
	
	func testThatAfterMergeInterrupted_UserIdentityRollsBack() {
        MMTestCase.startWithCorrectApplicationCode()
        
		weak var expectation = self.expectation(description: "expectation")
		mobileMessagingInstance.pushRegistrationId = "123"
		let user = MobileMessaging.getUser()!
		user.phones = ["1"]
		user.emails = ["2"]
		user.externalUserId = "3"
		
		performMergeInterruptedUserUpdateCase(user: user) {
			expectation?.fulfill()
		}
		
		waitForExpectations(timeout: 20, handler: { _ in
			let user = MobileMessaging.getUser()!
			XCTAssertNil(user.phones)
			XCTAssertNil(user.emails)
			XCTAssertNil(user.externalUserId)
		})
	}
	
	func testThatDirtyUserAttributesSentToServer() {
        MMTestCase.startWithCorrectApplicationCode()
        
		weak var expectation = self.expectation(description: "")
		var sent = [Any]()
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		
		let remoteApiProvider = RemoteAPIProviderStub()
		remoteApiProvider.patchUserClosure = { (_, _, requestBody) -> UpdateUserDataResult in
			sent.append(requestBody as Any)
			return UpdateUserDataResult.Success(EmptyResponse())
		}
		mobileMessagingInstance.remoteApiProvider = remoteApiProvider
		
		let user = MobileMessaging.getUser()!
		user.firstName = "A"
		user.customAttributes = ["string": "x" as NSString, "bool": true as NSNumber, "num": 9.5 as NSNumber, "bool2": true as NSNumber, "num2": 9.5 as NSNumber, "empty": "empty" as NSString]
		MobileMessaging.saveUser(user) { (error) in
			XCTAssertNil(error)
			
			let user = MobileMessaging.getUser()!
			user.firstName = "B"
			user.customAttributes = ["string": "y" as NSString, "bool": false as NSNumber, "num": 10 as NSNumber, "bool2": true as NSNumber, "num2": 9.5 as NSNumber, "empty": NSNull()]
			MobileMessaging.saveUser(user) { (error) in
				XCTAssertNil(error)
				expectation?.fulfill()
			}
		}
		waitForExpectations(timeout: 20, handler: { _ in
			let first = sent.first(where: { (element) -> Bool in
				(element as! NSDictionary).isEqual(to: ["firstName": "A", "customAttributes":["string": "x", "bool": true, "num": 9.5, "bool2": true, "num2": 9.5, "empty": "empty"]])
			})
			
			let second = sent.first(where: { (element) -> Bool in
				(element as! NSDictionary).isEqual(to: ["firstName": "B", "customAttributes":["string": "y", "bool": false, "num": 10, "empty": NSNull()]])
			})
			
			XCTAssertNotNil(first)
			XCTAssertNotNil(second)
		})
	}
	
	func testThatEmptyCustomAttributesSentAsNull() {
        MMTestCase.startWithCorrectApplicationCode()
        
		weak var expectation = self.expectation(description: "")
		var sent = [Any]()
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		
		let remoteApiProvider = RemoteAPIProviderStub()
		remoteApiProvider.patchUserClosure = { (_, _, requestBody) -> UpdateUserDataResult in
			sent.append(requestBody as Any)
			return UpdateUserDataResult.Success(EmptyResponse())
		}
		mobileMessagingInstance.remoteApiProvider = remoteApiProvider
		
		
		let user = MobileMessaging.getUser()!
		user.customAttributes = ["string": "x" as NSString, "bool": true as NSNumber, "num": 9.5 as NSNumber, "bool2": true as NSNumber, "num2": 9.5 as NSNumber]
		MobileMessaging.saveUser(user) { (error) in
			XCTAssertNil(error)
			
			let user = MobileMessaging.getUser()!
			user.customAttributes = [:]
			MobileMessaging.saveUser(user) { (error) in
				XCTAssertNil(error)
				expectation?.fulfill()
			}
		}
		waitForExpectations(timeout: 20, handler: { _ in
			let first = sent.first(where: { (element) -> Bool in
				(element as! NSDictionary).isEqual(to: ["customAttributes":["string": "x", "bool": true, "num": 9.5, "bool2": true, "num2": 9.5]])
			})
			
			let second = sent.first(where: { (element) -> Bool in
				(element as! NSDictionary).isEqual(to: ["customAttributes": NSNull()])
			})
			
			XCTAssertNotNil(first)
			XCTAssertNil(second)
		})
	}
}

func performMergeInterruptedUserUpdateCase(user: MMUser, then: (() -> Void)? = nil) {
	let remoteApiProvider = RemoteAPIProviderStub()
	remoteApiProvider.patchUserClosure = { (_, _, _) -> UpdateUserDataResult in
		let jsonStr = """
		{
			"requestError": {
				"serviceException" : {
					"messageId" : "USER_MERGE_INTERRUPTED",
					"text" : "something"
				}
			}
		}
	"""
		let requestError = MMRequestError(json: JSON.parse(jsonStr))
		return UpdateUserDataResult.Failure(requestError?.foundationError)
	}
	MobileMessaging.sharedInstance?.remoteApiProvider = remoteApiProvider
	MobileMessaging.saveUser(user, completion: { (error) in
		XCTAssertTrue(error!.mm_code == "USER_MERGE_INTERRUPTED" || error!.mm_code == "AMBIGUOUS_PERSONALIZE_CANDIDATES")
		then?()
	})
}
