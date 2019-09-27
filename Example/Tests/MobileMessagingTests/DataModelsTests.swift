//
//  ModelsTests.swift
//  MobileMessagingExample
//
//  Created by Andrey Kadochnikov on 14/01/2019.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import Foundation
import XCTest
@testable import MobileMessaging

class DataModelsTests: MMTestCase {


	let givenInstallation = Installation(applicationUserId: "applicationUserId",
										 appVersion: nil,
										 customAttributes: ["bootSize": 9.5 as NSNumber,
															"subscribed": true as NSNumber,
															"createdAt": NSDate(timeIntervalSince1970: 0)],
										 deviceManufacturer: "Apple",
										 deviceModel: "iPhone",
										 deviceName: "X",
										 deviceSecure: false,
										 deviceTimeZone: "GMT+03:30",
										 geoEnabled: false,
										 isPrimaryDevice: true,
										 isPushRegistrationEnabled: true,
										 language: nil,
										 notificationsEnabled: true,
										 os: "iOS",
										 osVersion: "12",
										 pushRegistrationId: "pushRegId",
										 pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil)

	func testPersonalizePayload() {
		let identity = UserIdentity(phones: ["1", "2"], emails: ["email"], externalUserId: nil)!
		let atts = UserAttributes(firstName: nil, middleName: "middleName", lastName: "lastName", tags: ["tags1", "tags2"], gender: .Male, birthday: Date.init(timeIntervalSince1970: 0), customAttributes: ["bootsize": NSNumber(value: 9)])
		let payload = UserDataMapper.personalizeRequestPayload(userIdentity: identity, userAttributes: atts)
		let expected: NSDictionary = [

			"userIdentity": [
				"emails": [
					["address": "email"]
				],
				"phones": [
					["number": "1"],
					["number": "2"]
				]
			],
			"userAttributes": [
				"middleName": "middleName",
				"lastName": "lastName",
				"tags": ["tags1","tags2"],
				"birthday": "1970-01-01",
				"gender": "Male",
				"customAttributes": [ "bootsize": NSNumber(value: 9) ]
			]
		]

		XCTAssertEqual(payload! as NSDictionary, expected)
	}

	func testUserDataPayload() {
		// date
		do {
			User.resetDirty()//dup
			User.resetCurrent()

			let comps = NSDateComponents()
			comps.year = 2016
			comps.month = 12
			comps.day = 31
			comps.hour = 23
			comps.minute = 55
			comps.second = 00
			comps.timeZone = TimeZone(secondsFromGMT: 5*60*60) // has expected timezone
			comps.calendar = Calendar(identifier: Calendar.Identifier.gregorian)
			let date = comps.date!

			let user = MobileMessaging.getUser()!
			user.firstName = "JohnDow1"
			user.birthday = date
			user.customAttributes = ["registrationDate": date as NSDate]
			user.archiveDirty()

			let body = UserDataMapper.requestPayload(currentUser: mobileMessagingInstance.currentUser(), dirtyUser: mobileMessagingInstance.dirtyUser())
			let request = PatchUser(applicationCode: "", pushRegistrationId: "", body: body, returnInstance: false, returnPushServiceToken: false)!

			let expectedDict: NSDictionary = [
				"firstName": "JohnDow1",
				"birthday": "2016-12-31",
				"customAttributes": [
					"registrationDate" : "2016-12-31"
				]
			]
			XCTAssertEqual((request.body! as NSDictionary), expectedDict)
		}

		// number
		do {
			User.resetDirty()//dup
			User.resetCurrent()

			let user = MobileMessaging.getUser()!
			user.firstName = "JohnDow2"
			user.externalUserId = "externalUserId2"
			user.customAttributes = ["bootsize": 9.5 as NSNumber]
			user.archiveDirty()

			let body = UserDataMapper.requestPayload(currentUser: mobileMessagingInstance.currentUser(), dirtyUser: mobileMessagingInstance.dirtyUser())
			let request = PatchUser(applicationCode: "", pushRegistrationId: "", body: body, returnInstance: false, returnPushServiceToken: false)!

			let expectedDict: NSDictionary = [
				"firstName": "JohnDow2",
				"externalUserId": "externalUserId2",
				"customAttributes": [
					"bootsize" : 9.5
				]
			]
			XCTAssertEqual((request.body! as NSDictionary), expectedDict)
		}

		//phones, emails
		do {
			User.resetDirty()
			User.resetCurrent()

			let user = MobileMessaging.getUser()!
			user.emails = ["1@mail.com"]
			user.phones = ["1"]
			user.archiveDirty()

			let body = UserDataMapper.requestPayload(currentUser: mobileMessagingInstance.currentUser(), dirtyUser: mobileMessagingInstance.dirtyUser())
			let request = PatchUser(applicationCode: "", pushRegistrationId: "", body: body, returnInstance: false, returnPushServiceToken: false)!

			let expectedDict: NSDictionary = [
				"phones": [["number": "1"]],
				"emails": [["address": "1@mail.com"]],
				]
			XCTAssertEqual((request.body! as NSDictionary), expectedDict)
		}

		// nils
		do {
			User.resetDirty()
			User.resetCurrent()

			let user = MobileMessaging.getUser()!
			user.firstName = "JohnDow3"
			user.externalUserId = "externalUserId3"
			user.archiveCurrent()

			user.firstName = nil
			user.externalUserId = nil
			user.archiveDirty()

			let body = UserDataMapper.requestPayload(currentUser: mobileMessagingInstance.currentUser(), dirtyUser: mobileMessagingInstance.dirtyUser())
			let request = PatchUser(applicationCode: "", pushRegistrationId: "", body: body, returnInstance: false, returnPushServiceToken: false)!

			let expectedDict: NSDictionary = [
				"firstName": NSNull(),
				"externalUserId": NSNull()
			]
			XCTAssertEqual((request.body! as NSDictionary), expectedDict)
		}

		// null
		do {
			User.resetDirty()
			User.resetCurrent()

			let user = MobileMessaging.getUser()!
			user.firstName = "JohnDow4"
			user.externalUserId = "externalUserId4"
			user.customAttributes = ["registrationDate": NSNull()]
			user.archiveDirty()

			let body = UserDataMapper.requestPayload(currentUser: mobileMessagingInstance.currentUser(), dirtyUser: mobileMessagingInstance.dirtyUser())
			let request = PatchUser(applicationCode: "", pushRegistrationId: "", body: body, returnInstance: false, returnPushServiceToken: false)!

			let expectedDict: NSDictionary = [
				"firstName": "JohnDow4",
				"externalUserId": "externalUserId4",
				"customAttributes": [
					"registrationDate" : NSNull()
				]
			]
			XCTAssertEqual((request.body! as NSDictionary), expectedDict)
		}
	}

	func testInstallationDataPayloadMapperForPatchRequest() {
		let installation = MobileMessaging.getInstallation()!
		installation.applicationUserId = "applicationUserId"
		installation.pushRegistrationId = "pushRegistrationId"

		installation.archiveCurrent()

		installation.customAttributes = ["dateField": NSDate(timeIntervalSince1970: 0),
										 "numberField": NSNumber(floatLiteral: 1.1),
										 "stringField": "foo" as NSString,
										 "nullString": NSNull()
										]
		installation.isPrimaryDevice = true
		installation.isPushRegistrationEnabled = false

		installation.archiveDirty()

		MobileMessaging.userAgent = UserAgentStub()
		let body = InstallationDataMapper.patchRequestPayload(currentInstallation: mobileMessagingInstance.currentInstallation(), dirtyInstallation: mobileMessagingInstance.dirtyInstallation(), internalData: mobileMessagingInstance.internalData())
		let request = PatchInstance(applicationCode: "", authPushRegistrationId: "", refPushRegistrationId: "", body: body, returnPushServiceToken: false)!

		let expectedDict: NSDictionary = [
			"customAttributes": ["dateField": "1970-01-01",
								 "numberField": 1.1,
								 "stringField": "foo",
								 "nullString": NSNull()],
			"isPrimary": true,
			"regEnabled": false,
			"geoEnabled": false,
			"notificationsEnabled": true,
			"pushServiceType": "APNS",
			"osVersion": "1.0",
			"deviceSecure": true,
			"appVersion": "1.0",
			"sdkVersion": "1.0.0",
			"deviceManufacturer": "GoogleApple",
			"deviceModel": "XS",
			"language": "en",
			"deviceName": "iPhone Galaxy",
			"os": "mobile OS",
			"deviceTimezoneOffset" : "GMT+03:30"
		]
		XCTAssertEqual((request.body! as NSDictionary), expectedDict)
	}

	func testThatCustomAttributesDeltaIsCorrect_regression() {
		let installation = MobileMessaging.getInstallation()!
		installation.customAttributes = [:]
		installation.archiveCurrent()

		installation.customAttributes = [:]
		installation.archiveDirty()

		let body = InstallationDataMapper.patchRequestPayload(currentInstallation: mobileMessagingInstance.currentInstallation(), dirtyInstallation: mobileMessagingInstance.dirtyInstallation(), internalData: mobileMessagingInstance.internalData())

		XCTAssertNil(body["customAttributes"])
	}

	func testThatCustomAttributesDeltaIsCorrect_regression2() {
		let installation = MobileMessaging.getInstallation()!
		installation.customAttributes = ["1":"2"] as [String : AttributeType]
		installation.archiveCurrent()

		installation.customAttributes = [:]
		installation.archiveDirty()

		let body = InstallationDataMapper.patchRequestPayload(currentInstallation: mobileMessagingInstance.currentInstallation(), dirtyInstallation: mobileMessagingInstance.dirtyInstallation(), internalData: mobileMessagingInstance.internalData())

		XCTAssertNotNil(body["customAttributes"])
	}

	func testInstallationDataPayloadMapperForPostRequest() {

		let installation = MobileMessaging.getInstallation()!

		installation.applicationUserId = "applicationUserId"
		installation.pushRegistrationId = "pushRegistrationId"

		installation.archiveCurrent()

		installation.customAttributes = ["dateField": NSDate(timeIntervalSince1970: 0),
										 "numberField": NSNumber(floatLiteral: 1.1),
										 "stringField": "foo" as NSString,
										 "nullString": NSNull()
		]
		installation.isPrimaryDevice = true
		installation.isPushRegistrationEnabled = false

		installation.archiveDirty()

		MobileMessaging.userAgent = UserAgentStub()
		let body = InstallationDataMapper.postRequestPayload(dirtyInstallation: mobileMessagingInstance.dirtyInstallation(), internalData: mobileMessagingInstance.internalData())
		let request = PatchInstance(applicationCode: "", authPushRegistrationId: "", refPushRegistrationId: "", body: body, returnPushServiceToken: false)!

		let expectedDict: NSDictionary = [
			"applicationUserId": "applicationUserId",
			"pushRegId": "pushRegistrationId",
			"customAttributes": ["dateField": "1970-01-01",
								 "numberField": 1.1,
								 "stringField": "foo",
								 "nullString": NSNull()],
			"isPrimary": true,
			"regEnabled": false,
			"geoEnabled": false,
			"notificationsEnabled": true,
			"pushServiceType": "APNS",
			"osVersion": "1.0",
			"deviceSecure": true,
			"appVersion": "1.0",
			"sdkVersion": "1.0.0",
			"deviceManufacturer": "GoogleApple",
			"deviceModel": "XS",
			"language": "en",
			"deviceName": "iPhone Galaxy",
			"os": "mobile OS",
			"deviceTimezoneOffset" : "GMT+03:30"
		]
		XCTAssertEqual((request.body! as NSDictionary), expectedDict)
	}

	func testInstallationObjectsConstructor() {
		let json = JSON.parse("""
		{
			"pushRegId": "pushRegId",
			"isPrimary": true,
			"regEnabled": true,
			"deviceManufacturer": "Apple",
			"deviceModel": "iPhone",
			"deviceName": "X",
			"osVersion": "12",
			"notificationsEnabled": true,
			"os": "iOS",
			"applicationUserId": "applicationUserId",
			"deviceTimezoneOffset": "GMT+03:30",
			"customAttributes": {
				"bootSize": 9.5,
				"subscribed": true,
				"createdAt": "1970-01-01"
			}
		}
"""
		)
		let i2 = Installation(json: json)

		XCTAssertEqual(givenInstallation, i2)
	}

	func testUserObjectsConstructor() {
		let u1 = User(externalUserId: "externalUserId",
					  firstName: "firstName",
					  middleName: "middleName",
					  lastName: "lastName",
					  phones: ["gsms1", "gsms2"],
					  emails: ["emails1", "emails2"],
					  tags: ["tag1", "tag2"],
					  gender: .Male,
					  birthday: Date(timeIntervalSince1970: 0),
					  customAttributes: ["bootSize": NSNumber(value: 9.5),
										 "subscribed": NSNumber(value: true),
										 "createdAt": NSDate(timeIntervalSince1970: 0)],
					  installations: [givenInstallation])


		let json = JSON.parse("""
		{
			"externalUserId": "externalUserId",
			"firstName": "firstName",
			"middleName": "middleName",
			"lastName": "lastName",
			"phones": [
				{
					"number": "gsms1"
				},
				{
					"number": "gsms2"
				}
			],
			"emails": [
				{
					"address": "emails1"
				},
				{
					"address": "emails2"
				}
			],
			"tags": [
				"tag1", "tag2"
			],
			"gender": "Male",
			"birthday": "1970-01-01",
			"customAttributes": {
				"bootSize": 9.5,
				"subscribed": true,
				"createdAt": "1970-01-01"
			},
			"instances": [
				{
					"pushRegId": "pushRegId",
					"isPrimary": true,
					"regEnabled": true,
					"deviceManufacturer": "Apple",
					"deviceModel": "iPhone",
					"deviceName": "X",
					"osVersion": "12",
					"notificationsEnabled": true,
					"os": "iOS",
					"applicationUserId": "applicationUserId",
					"deviceTimezoneOffset" : "GMT+03:30",
					"customAttributes": {
						"bootSize": 9.5,
						"subscribed": true,
						"createdAt": "1970-01-01"
					}
				}
			]
		}
""")

		let u2 = User(json: json)!
		XCTAssertEqual(u1, u2)
	}
}

