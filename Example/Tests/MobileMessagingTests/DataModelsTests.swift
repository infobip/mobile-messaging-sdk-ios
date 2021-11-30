//
//  ModelsTests.swift
//  MobileMessagingExample
//
//  Created by Andrey Kadochnikov on 14/01/2019.
//
//

import Foundation
import XCTest
@testable import MobileMessaging

class DataModelsTests: MMTestCase {
	let givenInstallation = MMInstallation(applicationUserId: "applicationUserId",
										 appVersion: nil,
										 customAttributes: ["bootSize": 9.5 as NSNumber,
															"subscribed": true as NSNumber,
															"createdAt": NSDate(timeIntervalSince1970: 0),
															"dateTime": MMDateTime(date: Date(timeIntervalSince1970: 0))],
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
		let identity = MMUserIdentity(phones: ["1", "2"], emails: ["email"], externalUserId: nil)!
		let atts = MMUserAttributes(firstName: nil, middleName: "middleName", lastName: "lastName", tags: ["tags1"], gender: .Male, birthday: Date.init(timeIntervalSince1970: 0), customAttributes: ["bootsize": NSNumber(value: 9)])
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
				"tags": ["tags1"],
				"birthday": "1970-01-01",
				"gender": "Male",
				"customAttributes": [ "bootsize": NSNumber(value: 9) ]
			]
		]
		XCTAssertEqual(payload! as NSDictionary, expected)
	}
	
	func testUserDataPayload() {
		MMTestCase.startWithCorrectApplicationCode()
		// datetime
		do {
			MMUser.resetDirty()
			MMUser.resetCurrent()
			
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
			user.customAttributes = ["registrationDateTime": MMDateTime(date: date) ]
			user.archiveDirty()
			
			let body = UserDataMapper.requestPayload(currentUser: mobileMessagingInstance.currentUser(), dirtyUser: mobileMessagingInstance.dirtyUser())
			let request = PatchUser(applicationCode: "", pushRegistrationId: "", body: body, returnInstance: false, returnPushServiceToken: false)!
			
			let expectedDict: NSDictionary = [
				"customAttributes": [
					"registrationDateTime" : "2016-12-31T18:55:00Z"
				]
			]
			XCTAssertEqual((request.body! as NSDictionary), expectedDict)
		}
		
		// list
		do {
			MMUser.resetDirty()
			MMUser.resetCurrent()
			
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
			user.customAttributes = [
				"list": [
					["registrationDate": date as NSDate, "bootsize": 9.5 as NSNumber, "nothing": NSNull(), "isEmployee": true as NSNumber],
					["registrationDate": date as NSDate, "bootsize": 10 as NSNumber, "nothing": NSNull(), "isEmployee": false as NSNumber]
				] as NSArray
			]
			user.archiveDirty()
			
			let body = UserDataMapper.requestPayload(currentUser: mobileMessagingInstance.currentUser(), dirtyUser: mobileMessagingInstance.dirtyUser())
			let request = PatchUser(applicationCode: "", pushRegistrationId: "", body: body, returnInstance: false, returnPushServiceToken: false)!
			
			let expectedDict: NSDictionary = [
				"customAttributes": [
					"list": [
						["registrationDate" : "2016-12-31", "bootsize" : 9.5,"nothing": NSNull(),"isEmployee": true],
						["registrationDate" : "2016-12-31", "bootsize" : 10,"nothing": NSNull(),"isEmployee": false]
					]
				]
			]
			XCTAssertEqual((request.body! as NSDictionary), expectedDict)
		}
		
		// date
		do {
			MMUser.resetDirty()//dup
			MMUser.resetCurrent()
			
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
			MMUser.resetDirty()//dup
			MMUser.resetCurrent()
			
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
			MMUser.resetDirty()
			MMUser.resetCurrent()
			
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
			MMUser.resetDirty()
			MMUser.resetCurrent()
			
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
			MMUser.resetDirty()
			MMUser.resetCurrent()
			
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
		self.waitForExpectations(timeout: 20, handler: nil)
	}
	
	func testInstallationDataPayloadMapperForPatchRequest() {
		MMTestCase.startWithCorrectApplicationCode()
		
		let installation = MobileMessaging.getInstallation()!
		installation.applicationUserId = "applicationUserId"
		installation.pushRegistrationId = "pushRegistrationId"
		
		installation.archiveCurrent()
		
		installation.customAttributes = ["dateField": NSDate(timeIntervalSince1970: 0),
										 "numberField": NSNumber(floatLiteral: 1.1),
										 "stringField": "foo" as NSString,
										 "nullString": NSNull(),
										 "dateTime": MMDateTime(date: Date(timeIntervalSince1970: 0))]
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
								 "nullString": NSNull(),
								 "dateTime": "1970-01-01T00:00:00Z"],
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
		self.waitForExpectations(timeout: 20, handler: nil)
	}
	
	func testThatCustomAttributesDeltaIsCorrect_regression() {
		MMTestCase.startWithCorrectApplicationCode()
		
		let installation = MobileMessaging.getInstallation()!
		installation.customAttributes = [:]
		installation.archiveCurrent()
		
		installation.customAttributes = [:]
		installation.archiveDirty()
		
		let body = InstallationDataMapper.patchRequestPayload(currentInstallation: mobileMessagingInstance.currentInstallation(), dirtyInstallation: mobileMessagingInstance.dirtyInstallation(), internalData: mobileMessagingInstance.internalData())
		
		XCTAssertNil(body["customAttributes"])
		self.waitForExpectations(timeout: 20, handler: nil)
	}
	
	func testThatCustomAttributesChangedFromNonEmptyToEmptyShouldBeSentAsEmpty_regression2() {
		MMTestCase.startWithCorrectApplicationCode()
		
		let installation = MobileMessaging.getInstallation()!
		installation.customAttributes = ["1":"2"] as [String : MMAttributeType]
		installation.archiveCurrent()
		
		installation.customAttributes = [:]
		installation.archiveDirty()
		
		let body = InstallationDataMapper.patchRequestPayload(currentInstallation: mobileMessagingInstance.currentInstallation(), dirtyInstallation: mobileMessagingInstance.dirtyInstallation(), internalData: mobileMessagingInstance.internalData())
		
		XCTAssertNotNil(body["customAttributes"])
		XCTAssertTrue((body["customAttributes"] as! [String : MMAttributeType]).isEmpty)
		self.waitForExpectations(timeout: 20, handler: nil)
	}
	
	func testThatUnsupportedDatatypeElementMustBeOmitted() {
		MMTestCase.startWithCorrectApplicationCode()
		
		MMUser.resetDirty()
		MMUser.resetCurrent()
		
		let user = MobileMessaging.getUser()!
		user.customAttributes = [
			"list": [
				["unsupportedTypeValue": NSData()]
			] as NSArray
		]
		user.archiveDirty()
		
		let body = UserDataMapper.requestPayload(currentUser: mobileMessagingInstance.currentUser(), dirtyUser: mobileMessagingInstance.dirtyUser())
		XCTAssertNil(body)
		self.waitForExpectations(timeout: 20, handler: nil)
	}
	
	func testThatCustomAttributesWithNoDifferenceShouldNotBeSent() {
		MMTestCase.startWithCorrectApplicationCode()
		
		let installation = MobileMessaging.getInstallation()!
		installation.customAttributes = ["1":"2"] as [String : MMAttributeType]
		installation.archiveCurrent()
		
		installation.customAttributes = [:]
		installation.archiveDirty()
		
		installation.customAttributes = ["1":"2"] as [String : MMAttributeType]
		installation.archiveDirty()
		
		let body = InstallationDataMapper.patchRequestPayload(currentInstallation: mobileMessagingInstance.currentInstallation(), dirtyInstallation: mobileMessagingInstance.dirtyInstallation(), internalData: mobileMessagingInstance.internalData())
		
		XCTAssertNil(body["customAttributes"])
		self.waitForExpectations(timeout: 20, handler: nil)
	}
	
	func testInstallationDataPayloadMapperForPostRequest() {
		MMTestCase.startWithCorrectApplicationCode()
		
		let installation = MobileMessaging.getInstallation()!
		
		installation.applicationUserId = "applicationUserId"
		installation.pushRegistrationId = "pushRegistrationId"
		
		installation.archiveCurrent()
		
		installation.customAttributes = ["dateField": NSDate(timeIntervalSince1970: 0),
										 "numberField": NSNumber(floatLiteral: 1.1),
										 "stringField": "foo" as NSString,
										 "nullString": NSNull(),
										 "dateTime": MMDateTime(date: Date(timeIntervalSince1970: 0))]
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
								 "nullString": NSNull(),
								 "dateTime": "1970-01-01T00:00:00Z"],
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
		self.waitForExpectations(timeout: 20, handler: nil)
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
				"createdAt": "1970-01-01",
				"dateTime": "1970-01-01T00:00:00Z"
			}
		}
"""
		)
		let i2 = MMInstallation(json: json)
		
		XCTAssertEqual(givenInstallation, i2)
	}
	
	func testUserObjectsConstructor() {
		let u1 = MMUser(externalUserId: "externalUserId",
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
						"createdAt": "1970-01-01",
						"dateTime": "1970-01-01T00:00:00Z"
					}
				}
			]
		}
""")
		
		let u2 = MMUser(json: json)!
		XCTAssertEqual(u1, u2)
	}
	
	
	func testCustomAttributesValidation() {
		do {
			let atts: [String: MMAttributeType] = [
				"name": "Andrey" as NSString,
				"list": [
					["registrationDate": Date() as NSDate, "bootsize": 9.5 as NSNumber, "nothing": NSNull(), "isEmployee": true as NSNumber],
					["registrationDate": Date() as NSDate, "bootsize": 10 as NSNumber, "nothing": NSNull(), "isEmployee": false as NSNumber, "data": NSData()]
				] as NSArray,
				"list2": [
					["name": "andrey"],
					["name": "john"]
				] as NSArray,
				"list3": [
					["name": ["name": "john"]]
				] as NSArray
			]
			XCTAssert(atts.validateListObjectsContainOnlySupportedTypes() == false)
			XCTAssert(atts.validateListObjectsHaveTheSameStructure() == false)
		}
		
		do {
			let atts: [String: MMAttributeType] = [
				"name": "Andrey" as NSString,
				"list": [
					["registrationDate": Date() as NSDate, "bootsize": 9.5 as NSNumber, "nothing": NSNull(), "isEmployee": true as NSNumber],
					["registrationDate": Date() as NSDate, "bootsize": 10 as NSNumber, "nothing": NSNull(), "Employee": true as NSNumber]
				] as NSArray,
				"list2": [
					["name": "andrey"],
					["name": "john"]
				] as NSArray,
				"list3": [
					["name": ["name": "john"]]
				] as NSArray
			]
			XCTAssert(atts.validateListObjectsContainOnlySupportedTypes() == false)
			XCTAssert(atts.validateListObjectsHaveTheSameStructure() == false)
		}
		
		do {
			let atts: [String: MMAttributeType] = [
				"name": "Andrey" as NSString,
				"list": [
					["registrationDate": Date() as NSDate, "bootsize": 9.5 as NSNumber, "nothing": NSNull(), "isEmployee": true as NSNumber],
					["registrationDate": Date() as NSDate, "bootsize": 10 as NSNumber, "nothing": NSNull(), "isEmployee": "false"]
				] as NSArray,
				"list2": [
					["name": "andrey"],
					["name": "john"]
				] as NSArray
			]
			XCTAssert(atts.validateListObjectsContainOnlySupportedTypes() == true)
			XCTAssert(atts.validateListObjectsHaveTheSameStructure() == false)
		}
		
		do {
			let atts: [String: MMAttributeType] = [
				"name": "Andrey" as NSString,
				"list": [
					["registrationDate": Date() as NSDate, "bootsize": 9.5 as NSNumber, "nothing": NSNull(), "isEmployee": true as NSNumber],
					["registrationDate": Date() as NSDate, "bootsize": 10 as NSNumber, "nothing": NSNull(), "isEmployee": false as NSNumber]
				] as NSArray,
				"list2": [
					["name": "andrey"],
					["name": "john"]
				] as NSArray,
				"list3": [
					["name": ["name": "john"]]
				] as NSArray
			]
			XCTAssert(atts.validateListObjectsContainOnlySupportedTypes() == false)
			XCTAssert(atts.validateListObjectsHaveTheSameStructure() == true)
		}
		
		do {
			let atts: [String: MMAttributeType] = [
				"name": "Andrey" as NSString,
				"list": [
					["registrationDate": Date() as NSDate, "bootsize": 9.5 as NSNumber, "nothing": NSNull(), "isEmployee": true as NSNumber],
					["registrationDate": Date() as NSDate, "bootsize": 10 as NSNumber, "nothing": NSNull(), "isEmployee": false as NSNumber]
				] as NSArray,
				"list2": [
					["name": "andrey"],
					["name": "john"]
				] as NSArray
			]
			XCTAssert(atts.validateListObjectsContainOnlySupportedTypes() == true)
			XCTAssert(atts.validateListObjectsHaveTheSameStructure() == true)
		}
		
		do {
			let atts: [String: MMAttributeType] = ["dateField": NSDate(timeIntervalSince1970: 0),
												 "numberField": NSNumber(floatLiteral: 1.1),
												 "stringField": "foo" as NSString,
												 "nullString": NSNull(),
												 "dateTime": MMDateTime(date: Date(timeIntervalSince1970: 0))]
			XCTAssert(atts.validateListObjectsContainOnlySupportedTypes() == true)
			XCTAssert(atts.validateListObjectsHaveTheSameStructure() == true)
		}
	}
}

