//
//  CodingDecodingTests.swift
//  MobileMessagingExample
//
//  Created by Olga Koroleva on 09.10.2023..
//

import Foundation

import XCTest
import Foundation
@testable import MobileMessaging
import CoreLocation

class CodingDecodingTests: MMTestCase {
    let testUser = MMUser(
        externalUserId: "externalUserId",
        firstName: "Darth",
        middleName: "midname",
        lastName: "Vader",
        phones: ["79214444444"],
        emails: ["darth@vader.com"],
        tags: ["tag1", "tag2"],
        gender: .Male,
        birthday: Date(),
        customAttributes: [
            "height": 189.5 as NSNumber,
            "nativePlace": "Tatooine" as NSString,
            "dateOfDeath": darthVaderDateOfDeath as NSDate,
            "dateTime": MMDateTime(date: Date(timeIntervalSince1970: 0))
        ],
        installations: [
            MMInstallation(
                applicationUserId: "applicationUserId",
                appVersion: nil,
                customAttributes: [
                    "home": "Death Star" as NSString,
                    "height": 189.5 as NSNumber,
                    "dateOfDeath": darthVaderDateOfDeath as NSDate,
                    "dateTime": MMDateTime(date: Date(timeIntervalSince1970: 0))
                ],
                deviceManufacturer: nil,
                deviceModel: nil,
                deviceName: nil,
                deviceSecure: true,
                deviceTimeZone: nil,
                geoEnabled: true,
                isPrimaryDevice: true,
                isPushRegistrationEnabled: true,
                language: nil,
                notificationsEnabled: true,
                os: "iOS",
                osVersion: nil,
                pushRegistrationId: "pushRegId1",
                pushServiceToken: nil,
                pushServiceType: nil,
                sdkVersion: nil)
        ]
    )
    
    let testInternalData = InternalData(
        systemDataHash: 12345,
        location: CLLocation(),
        badgeNumber: 5,
        applicationCode: "appCode",
        applicationCodeHash: "appCodeHash",
        depersonalizeFailCounter: 0,
        currentDepersonalizationStatus: MMSuccessPending.success,
        registrationDate: Date(),
        chatMessageCounter: 3
    )
    
    func testMMPhoneDecodedCorrectly() {
        let phone = MMPhone(number: "79214444444", preferred: false)
        let data = try! NSKeyedArchiver.archivedData(withRootObject: phone, requiringSecureCoding: true)
        let phoneUnarchieved = try! NSKeyedUnarchiver.unarchivedObject(ofClass: MMPhone.self, from: data)
        XCTAssertNotNil(phoneUnarchieved)
        XCTAssertEqual(phone.number, phoneUnarchieved!.number)
        XCTAssertEqual(phone.preferred, phoneUnarchieved!.preferred)
    }
    
    func testMMEmailDecodedCorrectly() {
        let email = MMEmail(address: "darth@vader.com", preferred: false)
        let data = try! NSKeyedArchiver.archivedData(withRootObject: email, requiringSecureCoding: true)
        let emailUnarchieved = try! NSKeyedUnarchiver.unarchivedObject(ofClass: MMEmail.self, from: data)
        XCTAssertNotNil(emailUnarchieved)
        XCTAssertEqual(email.address, emailUnarchieved!.address)
        XCTAssertEqual(email.preferred, emailUnarchieved!.preferred)
    }
    
    func testMMUserDecodedCorrectly() {
        let data = try! NSKeyedArchiver.archivedData(withRootObject: testUser, requiringSecureCoding: true)
        let userUnarchieved =  try! NSKeyedUnarchiver.unarchivedObject(ofClass: MMUser.self, from: data)
        
        //checking MMUser attributes
        XCTAssertNotNil(userUnarchieved)
        XCTAssertEqual(testUser.externalUserId, userUnarchieved!.externalUserId)
        XCTAssertEqual(userUnarchieved!.gender, MMGender.Male)
        XCTAssertEqual(userUnarchieved!.birthday, testUser.birthday)
        
        //checking MMPhone and MMEmail attributes
        XCTAssertEqual(testUser.phones!.first, userUnarchieved!.phones!.first)
        XCTAssertEqual(testUser.emails!.first, userUnarchieved!.emails!.first)
        
        //checking customAttributes
        XCTAssertNotNil(userUnarchieved!.customAttributes)
        XCTAssertEqual(testUser.customAttributes!["dateTime"] as! MMDateTime, userUnarchieved!.customAttributes!["dateTime"] as! MMDateTime)
        
        //checking MMInstallations attributes
        XCTAssertNotNil(userUnarchieved!.installations)
        XCTAssertEqual(testUser.installations!.first!.applicationUserId, userUnarchieved!.installations!.first!.applicationUserId)
        XCTAssertEqual(testUser.installations!.first!.isPrimaryDevice, userUnarchieved!.installations!.first!.isPrimaryDevice)
        XCTAssertNotNil(userUnarchieved!.installations!.first!.customAttributes)
    }
    
    func testInternalDataDecodedCorrectly() {
        let data = try! NSKeyedArchiver.archivedData(withRootObject: testInternalData, requiringSecureCoding: true)
        let internalDataUnarchieved =  try! NSKeyedUnarchiver.unarchivedObject(ofClass: InternalData.self, from: data)
        
        XCTAssertNotNil(internalDataUnarchieved)
        XCTAssertNotNil(internalDataUnarchieved!.location)
        XCTAssertEqual(testInternalData.chatMessageCounter , internalDataUnarchieved!.chatMessageCounter)
        XCTAssertEqual(testInternalData.currentDepersonalizationStatus , internalDataUnarchieved!.currentDepersonalizationStatus)
    }
    
    func testMMUserArchivedAndUnarchivedSuccessfully() {
        XCTAssertNotNil(testUser.archiveCurrent())
        
        let userUnarchieved = MMUser.unarchiveCurrent()
        
        //checking MMUser attributes
        XCTAssertNotNil(userUnarchieved)
        XCTAssertEqual(testUser.externalUserId, userUnarchieved.externalUserId)
        XCTAssertEqual(userUnarchieved.gender, MMGender.Male)
        XCTAssertEqual(userUnarchieved.birthday, testUser.birthday)
        
        //checking MMPhone and MMEmail attributes
        XCTAssertEqual(testUser.phones!.first, userUnarchieved.phones!.first)
        XCTAssertEqual(testUser.emails!.first, userUnarchieved.emails!.first)
        
        //checking customAttributes
        XCTAssertNotNil(userUnarchieved.customAttributes)
        
        //checking MMInstallations attributes
        XCTAssertNotNil(userUnarchieved.installations)
        XCTAssertEqual(testUser.installations!.first!.applicationUserId, userUnarchieved.installations!.first!.applicationUserId)
        XCTAssertEqual(testUser.installations!.first!.isPrimaryDevice, userUnarchieved.installations!.first!.isPrimaryDevice)
        XCTAssertNotNil(userUnarchieved.installations!.first!.customAttributes)
    }
    
    func testInternalDataArchivedAndUnarchivedSuccessfully() {
        XCTAssertNotNil(testInternalData.archiveCurrent())
        
        let internalDataUnarchieved = InternalData.unarchiveCurrent()
        
        XCTAssertNotNil(internalDataUnarchieved.location)
        XCTAssertEqual(testInternalData.chatMessageCounter , internalDataUnarchieved.chatMessageCounter)
        XCTAssertEqual(testInternalData.currentDepersonalizationStatus , internalDataUnarchieved.currentDepersonalizationStatus)
    }
    
    func testSharedDataStorageSuccessfullyUnarchivedMTMessage() {
        let jsonStr  = """
                        {
                            "messageId": "messageId",
                            "aps": {
                                "badge": 6,
                                "sound": "default",
                                "alert": {
                                    "body":"text"
                                }
                            },
                            "customPayload": {
                                "key": "value",
                                "nestedObject": {
                                    "key": "value"
                                }
                            }
                        }
                        """
        let message = MM_MTMessage(messageSyncResponseJson: JSON.parse(jsonStr))!
        let storage =  DefaultSharedDataStorage(applicationCode: "applicationCode", appGroupId: "appGroupId")
        storage?.save(message: message)
        let messages = storage?.retrieveMessages()
        XCTAssertNotNil(messages)
        XCTAssertEqual(messages!.first!.customPayload! as NSDictionary, ["key": "value", "nestedObject": ["key": "value"]] as NSDictionary)
    }
}
