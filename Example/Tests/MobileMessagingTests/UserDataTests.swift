//
//  UserDataTests.swift
//  MobileMessagingExample
//
//  Created by Andrey K. on 14/07/16.
//

import XCTest
@testable import MobileMessaging

class UserDataTests: MMTestCase {

	func testInstanceDataFetchingDecoding() {
		weak var expectation = self.expectation(description: "data fetched")
		mobileMessagingInstance.currentInstallation.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		let currentInstallation = MobileMessaging.currentInstallation!

		let responseStub: (Any) -> JSON? = { request -> JSON? in
			switch request {
			case (is GetInstance):
				let jsonStr = """
				{
					"notificationsEnabled": true,
					"pushRegId": "pushregid1",
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
				return JSON.parse(jsonStr)
			default:
				return nil
			}
		}

		mobileMessagingInstance.remoteApiProvider.registrationQueue = MMRemoteAPIMock(
			performRequestCompanionBlock: nil,
			completionCompanionBlock: nil,
			responseSubstitution: responseStub)

		currentInstallation.fetchFromServer(completion: { (user, error) in
			XCTAssertNil(error)
			XCTAssertEqual(currentInstallation.pushRegistrationId, "pushregid1")
			XCTAssertEqual(currentInstallation.isPrimaryDevice, true)
			XCTAssertEqual(currentInstallation.isPushRegistrationEnabled, true)
			XCTAssertEqual(currentInstallation.applicationUserId, "appUserId")
			XCTAssertEqual(currentInstallation.customAttribute(forKey: "Manufacturer") as? String, "_Apple_")
			XCTAssertEqual(currentInstallation.customAttribute(forKey: "Model") as? NSNumber, 1)
			XCTAssertEqual(currentInstallation.customAttribute(forKey: "ReleaseDate") as? NSDate, darthVaderDateOfDeath)
			expectation?.fulfill()
		})

		waitForExpectations(timeout: 20, handler: nil)
	}
	
	func testDataPersisting() {
		let currentUser = MobileMessaging.currentUser!
		_ = currentUser.set(customAttribute: "Crusher" as NSString, forKey: "nickname")
		currentUser.externalUserId = "someExternalId"
		currentUser.phones = ["123"]
		currentUser.emails = ["some@mail.com"]
		currentUser.birthday = darthVaderDateOfBirth
		currentUser.persist()

		XCTAssertEqual(currentUser.customAttribute(forKey: "nickname") as? NSString, "Crusher")
		XCTAssertEqual(currentUser.customAttributes?["nickname"] as? NSString, "Crusher")
		XCTAssertEqual(currentUser.externalUserId, "someExternalId")
		XCTAssertEqual(currentUser.phones, ["123"])
		XCTAssertEqual(currentUser.emails?.first, "some@mail.com")
		XCTAssertEqual(currentUser.birthday, darthVaderDateOfBirth)


		_ = currentUser.set(customAttribute: nil, forKey: "nilElement")
		XCTAssertTrue(currentUser.customAttributes?["nilElement"] is NSNull)

		XCTAssertEqual(Date(timeIntervalSince1970: 1468593199).toJSON(), "2016-07-15")

		let ctx = (self.mobileMessagingInstance.internalStorage.mainThreadManagedObjectContext!)
		ctx.reset()
		if let installation = InstallationManagedObject.MM_findFirstInContext(ctx) {

			XCTAssertTrue(installation.dirtyAttsSet.contains(Attributes.externalUserId))
			XCTAssertTrue(installation.dirtyAttsSet.contains(Attributes.phones))
			XCTAssertTrue(installation.dirtyAttsSet.contains(Attributes.customUserAttribute(key: "nickname")))

			XCTAssertEqual(installation.customUserAttributes?["nickname"] as? String, "Crusher")
			XCTAssertEqual(installation.phones, [Phone(number: "123", preferred: true)])
			XCTAssertEqual(installation.birthday, "1980-12-12")
			XCTAssertEqual(installation.emails?.first?.address, "some@mail.com")
			XCTAssertTrue(currentUser.standardAttributes!["nickname"] == nil, "custom data has nothing to do with predefined data")

			installation.resetDirtyAttribute(attributes: Attributes.customUserAttributes)
			XCTAssertFalse(installation.dirtyAttsSet.contains(Attributes.customUserAttributes))

		} else {
			XCTFail("There must be atleast one installation object in database")
		}
	}

	func testJsonDecoding() {
		weak var expectation = self.expectation(description: "data fetched")
		mobileMessagingInstance.currentInstallation.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		mobileMessagingInstance.currentInstallation.persist()
		let currentUser = MobileMessaging.currentUser!

		let responseStub: (Any) -> JSON? = { request -> JSON? in
			switch request {
			case (is GetUser):
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
			"car": null
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
				return JSON.parse(jsonStr)
			default:
				return nil
			}
		}

		mobileMessagingInstance.remoteApiProvider.registrationQueue = MMRemoteAPIMock(
			performRequestCompanionBlock: nil,
			completionCompanionBlock: nil,
			responseSubstitution: responseStub)

		currentUser.fetchFromServer(completion: { (user, error) in
			XCTAssertNil(error)

			XCTAssertNil(currentUser.customAttributes?["car"])

			let primaryInstallation = (currentUser.installations?.first(where: {$0.isPrimaryDevice}))!
			XCTAssertEqual(primaryInstallation.deviceModel, "iPhone 1")
		    XCTAssertEqual(primaryInstallation.deviceManufacturer, "Apple")
			XCTAssertEqual(primaryInstallation.pushRegistrationId, "pushregid1")
			XCTAssertEqual(primaryInstallation.deviceName, "Johns iPhone")
			XCTAssertEqual(primaryInstallation,
						   Installation(applicationUserId: nil, appVersion: nil, customAttributes: nil, deviceManufacturer: "Apple", deviceModel: "iPhone 1", deviceName: "Johns iPhone", deviceSecure: false, deviceTimeZone: nil, geoEnabled: false, isPrimaryDevice: true, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: "iOS", osVersion: nil, pushRegistrationId: "pushregid1", pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil)
			)

			let secondaryInstallation = (currentUser.installations?.first(where: {!$0.isPrimaryDevice}))!
			XCTAssertEqual(secondaryInstallation.deviceModel, "Galaxy")
			XCTAssertEqual(secondaryInstallation.deviceManufacturer, "Samsung")
			XCTAssertEqual(secondaryInstallation.pushRegistrationId, "pushregid2")
			XCTAssertEqual(secondaryInstallation.deviceName, "Johns Sam")
			XCTAssertEqual(secondaryInstallation,
						   Installation(applicationUserId: nil, appVersion: nil, customAttributes: nil, deviceManufacturer: "Samsung", deviceModel: "Galaxy", deviceName: "Johns Sam", deviceSecure: false, deviceTimeZone: nil, geoEnabled: false, isPrimaryDevice: false, isPushRegistrationEnabled: false, language: nil, notificationsEnabled: true, os: "Android", osVersion: nil, pushRegistrationId: "pushregid2", pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil)
			)

			XCTAssertTrue(currentUser.phones?.contains("1") ?? false)
			XCTAssertTrue(currentUser.phones?.contains("2") ?? false)

			XCTAssertTrue(currentUser.emails?.contains("1xxx@xxx.com") ?? false)
			XCTAssertTrue(currentUser.emails?.contains("2xxx@xxx.com") ?? false)

			XCTAssertEqual(currentUser.customAttributes?["nativePlace"] as? String, "Tatooine")
			XCTAssertEqual(currentUser.customAttributes?["height"] as? NSNumber, 189.5)
			XCTAssertEqual(currentUser.customAttributes?["dateOfDeath"] as? NSDate, darthVaderDateOfDeath)

			XCTAssertNil(currentUser.customAttribute(forKey: "car"))
			XCTAssertEqual(currentUser.customAttribute(forKey: "nativePlace") as? String, "Tatooine")
			XCTAssertEqual(currentUser.customAttribute(forKey: "height") as? NSNumber, 189.5)
			XCTAssertEqual(currentUser.customAttribute(forKey: "dateOfDeath") as? NSDate, darthVaderDateOfDeath)
			expectation?.fulfill()
		})

		waitForExpectations(timeout: 20, handler: nil)
	}

	func testUserDataFetching() {
		weak var expectation = self.expectation(description: "save completed")

		//Precondiotions
		mobileMessagingInstance.currentInstallation.pushRegistrationId = MMTestConstants.kTestCorrectInternalID

		let currentUser = MobileMessaging.currentUser!

		_ = currentUser.set(customAttribute: "Death Star" as NSString, forKey: "home")
		_ = currentUser.set(customAttribute: "Beer" as NSString, forKey: "drink")
		_ = currentUser.set(customAttribute: "Pizza" as NSString, forKey: "food")
		_ = currentUser.set(customAttribute: 189.5 as NSNumber, forKey: "height")

		currentUser.externalUserId = "externalUserId"
		currentUser.firstName = "Darth"
		currentUser.lastName = "Vader"
		currentUser.birthday = darthVaderDateOfBirth
		currentUser.gender = .Male

		currentUser.phones = ["79214444444"]
		currentUser.emails = ["darth@vader.com"]

		XCTAssertTrue(currentUser.isChanged)

		let remoteApiProvider = RemoteApiUserAttributesMock()
		remoteApiProvider.getClosure = { applicationCode, pushRegistrationId, completion in
			let response = User(externalUserId: nil, firstName: "Darth", middleName: nil, lastName: "Vader", phones: ["79214444444"], emails: ["darth@vader.com"], tags: nil, gender: .Male, birthday: DateStaticFormatters.ContactsServiceDateFormatter.date(from: "1980-12-12"), customAttributes: ["home": "Death Star" as NSString, "drink": "Beer" as NSString, "food": "Pizza" as NSString, "height": 189.5 as NSNumber, "nativePlace": "Tatooine" as NSString, "mentor": "Obi Wan Kenobi" as NSString, "dateOfDeath": darthVaderDateOfDeath as NSDate], installations: [Installation(applicationUserId: nil, appVersion: nil, customAttributes: nil, deviceManufacturer: nil, deviceModel: nil, deviceName: nil, deviceSecure: true, deviceTimeZone: nil, geoEnabled: true, isPrimaryDevice: true, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: "iOS", osVersion: nil, pushRegistrationId: "pushRegId1", pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil)])

			completion(FetchUserDataResult.Success(response))
		}
		mobileMessagingInstance.remoteApiProvider = remoteApiProvider

		currentUser.resetNeedToSync(attributesSet: Attributes.userDataAttributesSet) // explicitly reset dirty attributes to accomplish the successful fetching
		currentUser.persist()

		currentUser.fetchFromServer(completion: { (user, error) in
			XCTAssertNil(error)

			XCTAssertNil(currentUser.externalUserId)
			XCTAssertFalse(currentUser.isChanged)
			XCTAssertEqual(currentUser.firstName, "Darth")
			XCTAssertEqual(currentUser.lastName, "Vader")
			XCTAssertEqual(currentUser.birthday, darthVaderDateOfBirth)
			XCTAssertEqual(currentUser.gender, .Male)
			XCTAssertEqual(currentUser.phones, ["79214444444"])
			XCTAssertEqual(currentUser.emails?.first, "darth@vader.com")
			XCTAssertEqual(currentUser.installations, [Installation(applicationUserId: nil, appVersion: nil, customAttributes: nil, deviceManufacturer: nil, deviceModel: nil, deviceName: nil, deviceSecure: true, deviceTimeZone: nil, geoEnabled: true, isPrimaryDevice: true, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: "iOS", osVersion: nil, pushRegistrationId: "pushRegId1", pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil)])

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
		MMTestCase.cleanUpAndStop()
		MMTestCase.startWithCorrectApplicationCode()
		weak var expectation = self.expectation(description: "data received")
		mobileMessagingInstance.currentInstallation.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		let remoteApiProvider = RemoteApiUserAttributesMock()
		remoteApiProvider.getClosure = { applicationCode, pushRegistrationId, completion in
			let response = User(externalUserId: nil, firstName: "Darth", middleName: nil, lastName: "Vader", phones: ["79214444444"], emails: ["darth@vader.com"], tags: nil, gender: .Male, birthday: DateStaticFormatters.ContactsServiceDateFormatter.date(from: "1980-12-12"), customAttributes: ["home": "Death Star" as NSString, "drink": "Beer" as NSString, "food": "Pizza" as NSString, "height": 189.5 as NSNumber, "nativePlace": "Tatooine" as NSString, "mentor": "Obi Wan Kenobi" as NSString, "dateOfDeath": darthVaderDateOfDeath as NSDate], installations: nil)
			completion(FetchUserDataResult.Success(response))
		}

		let user = MobileMessaging.currentUser!
		user.persist()
		user.firstName = "John" // unsynced local change

		user.fetchFromServer { (_, _) in
			expectation?.fulfill()
		}

		waitForExpectations(timeout: 20, handler: { _ in
			XCTAssertEqual(user.firstName, "John") // must be preserved
		})
	}


	func testThatUserDataIsNotPersistedIfPrivacySettingsSpecified() {
		MobileMessaging.privacySettings.userDataPersistingDisabled = true

		let currentUser = MobileMessaging.currentUser!
		let currentInstallation = MobileMessaging.currentInstallation!

		currentUser.lastName = "Skywalker"
		currentUser.gender = .Male
		currentUser.emails = ["luke@starwars.com"]
		currentUser.phones = ["123"]
		currentInstallation.pushRegistrationId = "123"
		currentUser.externalUserId = "123"

		_ = currentUser.set(customAttribute: "Death Star" as NSString, forKey: "home")

		currentUser.persist()

		// assertions:
		let ctx = self.mobileMessagingInstance.currentInstallation.coreDataProvider.context
		ctx.performAndWait {
			let installation = InstallationManagedObject.MM_findFirstInContext(ctx)!
			// we havent stored on disk
			XCTAssertNil(installation.phones, "userdata must not be persisted")
			XCTAssertNil(installation.lastName, "userdata must not be persisted")
			XCTAssertNil(installation.gender, "userdata must not be persisted")
			XCTAssertNil(installation.emails, "userdata must not be persisted")
			XCTAssertNil(installation.customUserAttributes, "userdata must not be persisted")
			XCTAssertNil(installation.externalUserId, "userdata must not be persisted")
			XCTAssertEqual(installation.pushRegId, "123", "internal id must be persisted, since it's not an user data")
		}

		// but we still able to get data from memory
		XCTAssertEqual(currentInstallation.pushRegistrationId, "123")
		XCTAssertEqual(currentUser.emails?.first, "luke@starwars.com")
		XCTAssertEqual(currentUser.phones, ["123"])
		XCTAssertEqual(currentUser.externalUserId, "123")
		XCTAssertEqual(currentUser.lastName, "Skywalker")
		XCTAssertEqual(currentUser.gender, .Male)

		XCTAssertEqual(currentUser.customAttribute(forKey: "home") as? NSString, "Death Star")
	}

	func testThatUnwantedMergeErrorIsPorpagated() {
		weak var expectation = self.expectation(description: "data fetched")
		mobileMessagingInstance.currentInstallation.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		mobileMessagingInstance.currentInstallation.persist()
		let currentUser = MobileMessaging.currentUser!

		let responseStub: (Any) -> JSON? = { request -> JSON? in
			switch request {
			case (is PatchUser):
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
				return JSON.parse(jsonStr)
			default:
				return nil
			}
		}

		mobileMessagingInstance.remoteApiProvider.registrationQueue = MMRemoteAPIMock(
			performRequestCompanionBlock: nil,
			completionCompanionBlock: nil,
			responseSubstitution: responseStub)


		let user = MobileMessaging.user!
		user.firstName = "john"
		currentUser.save(userData: user) { (error) in
			XCTAssertNotNil(error)
			expectation?.fulfill()
		}
		waitForExpectations(timeout: 20, handler: nil)
	}
}

var darthVaderDateOfDeath: NSDate {
	let comps = NSDateComponents()
	comps.year = 1983
	comps.month = 5
	comps.day = 25
	comps.hour = 0
	comps.minute = 0
	comps.second = 0
	comps.timeZone = TimeZone(secondsFromGMT: 0) // has expected timezone
	comps.calendar = Calendar(identifier: Calendar.Identifier.gregorian)
	return comps.date! as NSDate
}

var darthVaderDateOfBirth: Date {
	let comps = NSDateComponents()
	comps.year = 1980
	comps.month = 12
	comps.day = 12
	comps.hour = 0
	comps.minute = 0
	comps.second = 0
	comps.timeZone = TimeZone(secondsFromGMT: 0) // has expected timezone
	comps.calendar = Calendar(identifier: Calendar.Identifier.gregorian)
	return comps.date!
}
