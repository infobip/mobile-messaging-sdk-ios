//
//  UserDataTests.swift
//  MobileMessagingExample
//
//  Created by Andrey K. on 14/07/16.
//

import XCTest
@testable import MobileMessaging

class UserDataTests: MMTestCase {

	func testDateJsonEncoding() {
		XCTAssertEqual(Date(timeIntervalSince1970: 1468593199).toJSON(), "2016-07-15")
	}

	func testDataPersisting() {
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
		waitForExpectations(timeout: 20, handler: { _ in
		})
	}

	func testJsonDecoding() {
		weak var expectation = self.expectation(description: "data fetched")
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID

		let currentUser = MobileMessaging.getUser()!

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
			responseStub: responseStub)

		mobileMessagingInstance.userService.fetchFromServer(completion: { (user, error) in
			XCTAssertNil(error)

			XCTAssertNil(currentUser.customAttributes?["car"])

			let primaryInstallation = (user.installations?.first(where: {$0.isPrimaryDevice}))!
			XCTAssertEqual(primaryInstallation.deviceModel, "iPhone 1")
		    XCTAssertEqual(primaryInstallation.deviceManufacturer, "Apple")
			XCTAssertEqual(primaryInstallation.pushRegistrationId, "pushregid1")
			XCTAssertEqual(primaryInstallation.deviceName, "Johns iPhone")
			XCTAssertEqual(primaryInstallation,
						   Installation(applicationUserId: nil, appVersion: nil, customAttributes: nil, deviceManufacturer: "Apple", deviceModel: "iPhone 1", deviceName: "Johns iPhone", deviceSecure: false, deviceTimeZone: nil, geoEnabled: false, isPrimaryDevice: true, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: "iOS", osVersion: nil, pushRegistrationId: "pushregid1", pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil)
			)

			let secondaryInstallation = (user.installations?.first(where: {!$0.isPrimaryDevice}))!
			XCTAssertEqual(secondaryInstallation.deviceModel, "Galaxy")
			XCTAssertEqual(secondaryInstallation.deviceManufacturer, "Samsung")
			XCTAssertEqual(secondaryInstallation.pushRegistrationId, "pushregid2")
			XCTAssertEqual(secondaryInstallation.deviceName, "Johns Sam")
			XCTAssertEqual(secondaryInstallation,
						   Installation(applicationUserId: nil, appVersion: nil, customAttributes: nil, deviceManufacturer: "Samsung", deviceModel: "Galaxy", deviceName: "Johns Sam", deviceSecure: false, deviceTimeZone: nil, geoEnabled: false, isPrimaryDevice: false, isPushRegistrationEnabled: false, language: nil, notificationsEnabled: true, os: "Android", osVersion: nil, pushRegistrationId: "pushregid2", pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil)
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
			expectation?.fulfill()
		})

		waitForExpectations(timeout: 20, handler: nil)
	}

	func testUserDataFetching() {
		weak var expectation = self.expectation(description: "save completed")

		//Precondiotions
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID

		let remoteApiProvider = RemoteApiUserAttributesMock()
		remoteApiProvider.getClosure = { applicationCode, pushRegistrationId, completion in
			let response = User(externalUserId: nil, firstName: "Darth", middleName: nil, lastName: "Vader", phones: ["79214444444"], emails: ["darth@vader.com"], tags: nil, gender: .Male, birthday: DateStaticFormatters.ContactsServiceDateFormatter.date(from: "1980-12-12"), customAttributes: ["home": "Death Star" as NSString, "drink": "Beer" as NSString, "food": "Pizza" as NSString, "height": 189.5 as NSNumber, "nativePlace": "Tatooine" as NSString, "mentor": "Obi Wan Kenobi" as NSString, "dateOfDeath": darthVaderDateOfDeath as NSDate], installations: [Installation(applicationUserId: nil, appVersion: nil, customAttributes: nil, deviceManufacturer: nil, deviceModel: nil, deviceName: nil, deviceSecure: true, deviceTimeZone: nil, geoEnabled: true, isPrimaryDevice: true, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: "iOS", osVersion: nil, pushRegistrationId: "pushRegId1", pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil)])

			completion(FetchUserDataResult.Success(response))
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
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		let remoteApiProvider = RemoteApiUserAttributesMock()
		remoteApiProvider.getClosure = { applicationCode, pushRegistrationId, completion in
			let response = User(externalUserId: nil, firstName: "Darth", middleName: nil, lastName: "Vader", phones: ["79214444444"], emails: ["darth@vader.com"], tags: nil, gender: .Male, birthday: DateStaticFormatters.ContactsServiceDateFormatter.date(from: "1980-12-12"), customAttributes: ["home": "Death Star" as NSString, "drink": "Beer" as NSString, "food": "Pizza" as NSString, "height": 189.5 as NSNumber, "nativePlace": "Tatooine" as NSString, "mentor": "Obi Wan Kenobi" as NSString, "dateOfDeath": darthVaderDateOfDeath as NSDate], installations: nil)
			completion(FetchUserDataResult.Success(response))
		}

		let user = MobileMessaging.getUser()!
		user.firstName = "John" // unsynced local change
		user.archiveDirty()

		mobileMessagingInstance.userService.fetchFromServer { (_, _) in
			expectation?.fulfill()
		}

		waitForExpectations(timeout: 20, handler: { _ in
			XCTAssertEqual(user.firstName, "John") // must be preserved
		})
	}


	func testThatUserDataIsNotPersistedIfPrivacySettingsSpecified() {
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
			let dirtyUser = NSKeyedUnarchiver.unarchiveObject(withFile: User.dirtyPath) as! User
			// we havent stored on disk
			XCTAssertNil(dirtyUser.phones, "userdata must not be persisted")
			XCTAssertNil(dirtyUser.lastName, "userdata must not be persisted")
			XCTAssertNil(dirtyUser.gender, "userdata must not be persisted")
			XCTAssertNil(dirtyUser.emails, "userdata must not be persisted")
			XCTAssertNil(dirtyUser.customAttributes, "userdata must not be persisted")
			XCTAssertNil(dirtyUser.externalUserId, "userdata must not be persisted")

			let currentUser = NSKeyedUnarchiver.unarchiveObject(withFile: User.currentPath) as! User
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
	}

	func testThatUnwantedMergeErrorIsPorpagated() {
		weak var expectation = self.expectation(description: "data fetched")
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID

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
			responseStub: responseStub)


		let user = MobileMessaging.getUser()!
		user.firstName = "john"
		MobileMessaging.saveUser(user) { (error) in
			XCTAssertNotNil(error)
			expectation?.fulfill()
		}
		waitForExpectations(timeout: 20, handler: nil)
	}

	func testThat_NO_REGISTRATION_errorLeadsToRegistrationAndUserDataReset() {
		weak var expectation = self.expectation(description: "data fetched")
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID

		let responseStub: (Any) -> JSON? = { request -> JSON? in
			switch request {
			case (is PatchUser), (is PostInstance), (is PatchInstance):
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
				return JSON.parse(jsonStr)
			default:
				return nil
			}
		}

		mobileMessagingInstance.remoteApiProvider.registrationQueue = MMRemoteAPIMock(
			performRequestCompanionBlock: nil,
			completionCompanionBlock: nil,
			responseStub: responseStub)


		let user = MobileMessaging.getUser()!
		user.firstName = "john"
		user.archiveAll()
		user.lastName = "dow"

		XCTAssertNotNil(self.mobileMessagingInstance.currentInstallation().pushRegistrationId)
		XCTAssertNotNil(self.mobileMessagingInstance.dirtyInstallation().pushRegistrationId)

		XCTAssertNotNil(self.mobileMessagingInstance.dirtyUser().firstName)
		XCTAssertNotNil(self.mobileMessagingInstance.currentUser().firstName)

		MobileMessaging.saveUser(user) { (error) in
			XCTAssertNotNil(error)

			XCTAssertNil(self.mobileMessagingInstance.currentInstallation().pushRegistrationId)
			XCTAssertNil(self.mobileMessagingInstance.dirtyInstallation().pushRegistrationId)

			XCTAssertNil(self.mobileMessagingInstance.currentUser().firstName)
			XCTAssertNil(self.mobileMessagingInstance.currentUser().lastName)

			XCTAssertNotNil(self.mobileMessagingInstance.dirtyUser().firstName)
			XCTAssertNotNil(self.mobileMessagingInstance.dirtyUser().lastName)

			expectation?.fulfill()
		}
		waitForExpectations(timeout: 20, handler: nil)
	}

	func testThatAfterMergeInterrupted_UserIdentityRollsBack() {
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
		weak var expectation = self.expectation(description: "")
		var sent = [Any]()
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID

		let requestBlock: (Any) -> Void = { request in
			switch request {
			case (is PatchUser):
				if let patchRequest = request as? PatchUser {
					sent.append(patchRequest.body as Any)
				}
			default:
				break
			}
		}

		let responseBlock: (Any) -> JSON? = { request -> JSON? in
			switch request {
			case (is PatchUser):
				return JSON.parse("")
			default:
				return nil
			}
		}
		mobileMessagingInstance.remoteApiProvider.registrationQueue = MMRemoteAPIMock(
			performRequestCompanionBlock: requestBlock,
			completionCompanionBlock: nil,
			responseStub: responseBlock)

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
		weak var expectation = self.expectation(description: "")
		var sent = [Any]()
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID

		let requestBlock: (Any) -> Void = { request in
			switch request {
			case (is PatchUser):
				if let patchRequest = request as? PatchUser {
					sent.append(patchRequest.body as Any)
				}
			default:
				break
			}
		}

		let responseBlock: (Any) -> JSON? = { request -> JSON? in
			switch request {
			case (is PatchUser):
				return JSON.parse("")
			default:
				return nil
			}
		}
		mobileMessagingInstance.remoteApiProvider.registrationQueue = MMRemoteAPIMock(
			performRequestCompanionBlock: requestBlock,
			completionCompanionBlock: nil,
			responseStub: responseBlock)

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
			XCTAssertNotNil(second)
		})
	}
}

func performMergeInterruptedUserUpdateCase(user: User, then: (() -> Void)? = nil) {
	MobileMessaging.sharedInstance?.remoteApiProvider.registrationQueue = mergeInterruptedApiMock
	MobileMessaging.saveUser(user, completion: { (error) in
		XCTAssertTrue(error!.mm_code == "USER_MERGE_INTERRUPTED" || error!.mm_code == "AMBIGUOUS_PERSONALIZE_CANDIDATES")
		then?()
	})
}

let mergeInterruptedApiMock = MMRemoteAPIMock(performRequestCompanionBlock: nil, completionCompanionBlock: nil, responseStub: { request -> JSON? in
	switch request {
	case is PatchUser:
		let responseDict = ["requestError":
			["serviceException":
				[
					"text": "USER_MERGE_INTERRUPTED",
					"messageId": "USER_MERGE_INTERRUPTED"
				]
			]
		]
		return JSON(responseDict)
	default:
		return nil
	}
})
