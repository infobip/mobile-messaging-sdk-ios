// 
//  Example/Tests/MobileMessagingTests/CodingDecodingTests.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2026 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

import XCTest
import Foundation
@testable import MobileMessaging
import CoreLocation

class CodingDecodingTests: MMTestCase {
    let testUser = MMUser(
        externalUserId: "externalUserId", 
        type: .Lead,
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
            "dateTime": MMDateTime(date: Date(timeIntervalSince1970: 0)),
            "nullAttribute": NSNull(),
            "favsList": [
                        ["id": "1", "price": 99.99, "sale": true],
                        ["id": "2", "price": 149.99, "sale": false],
                    ] as NSArray
        ],
        installations: [
            MMInstallation(
                applicationUserId: "applicationUserId",
                appVersion: nil,
                customAttributes: [
                    "home": "Death Star" as NSString,
                    "height": 189.5 as NSNumber,
                    "dateOfDeath": darthVaderDateOfDeath as NSDate,
                    "dateTime": MMDateTime(date: Date(timeIntervalSince1970: 0)),
                    "nullAttribute": NSNull(),
                    "favsList" : [
                                ["id": "1", "price": 99.99, "sale": true],
                                ["id": "2", "price": 149.99, "sale": false],
                            ] as NSArray
                ],
                deviceManufacturer: nil,
                deviceModel: nil,
                deviceName: nil,
                deviceSecure: true,
                deviceTimeZone: nil,
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
        depersonalizeFailCounter: 0,
        currentDepersonalizationStatus: MMSuccessPending.success,
        registrationDate: Date(),
        chatMessageCounter: 3
    )
    
    let userInfo: MMAPNSPayload = [
        AnyHashable("messageId"): "random-message-id-123456",
        AnyHashable("aps"): ["alert": ["body": "msg_body"]],
        AnyHashable("customPayload"):
            [
                "key": "value",
                "nestedObject": [
                    "key" : "value"
                ],
                "nullAttribute" : NSNull(),
                "numberAttribute" : 123 as NSNumber
            ],
    ]
    
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
        XCTAssertEqual(testUser.customAttributes!["nativePlace"] as! NSString, userUnarchieved!.customAttributes!["nativePlace"] as! NSString)
        XCTAssertEqual(testUser.customAttributes!["height"] as! NSNumber, userUnarchieved!.customAttributes!["height"] as! NSNumber)
        XCTAssertEqual(testUser.customAttributes!["dateOfDeath"] as! NSDate, userUnarchieved!.customAttributes!["dateOfDeath"] as! NSDate)
        XCTAssertEqual(testUser.customAttributes!["nullAttribute"] as! NSNull, userUnarchieved!.customAttributes!["nullAttribute"] as! NSNull)
        
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
    
    func testMMUserUnencryptedUnarchivedSuccessfullyWhenDecryptionIsOptionallyApplied() {
        // writing unencrypted user data on disk
        let dataToBeArchived = try! NSKeyedArchiver.archivedData(withRootObject: testUser, requiringSecureCoding: true)
        try! dataToBeArchived.write(to: URL(fileURLWithPath: MMUser.currentPath))
        
        // reading unencrypted user data
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
        let message = MM_MTMessage(payload: userInfo,
                                    deliveryMethod: .push,
                                    seenDate: nil,
                                    deliveryReportDate: nil,
                                    seenStatus: .NotSeen,
                                    isDeliveryReportSent: false)!
        let containerURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: containerURL) }

        let storage = DefaultSharedDataStorage(applicationCode: "applicationCode", appGroupId: "appGroupId", containerURL: containerURL)
        storage?.save(message: message)
        let messages = storage?.drainMessages()
        XCTAssertNotNil(messages)
        XCTAssertEqual(messages!.first!.customPayload! as NSDictionary, userInfo["customPayload"] as! NSDictionary)
    }
    
    func testThatMTMessagePayloadCorrectlyTransformed() {
        MMTestCase.startWithCorrectApplicationCode()
        
        weak let expectation = self.expectation(description: "expectation")
        let messageReceivingGroup = DispatchGroup()
        
        messageReceivingGroup.enter()
        mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: userInfo, completion: { _ in
            messageReceivingGroup.leave()
        })
        
        messageReceivingGroup.notify(queue: DispatchQueue.main) {
            let ctx = self.storage.mainThreadManagedObjectContext!
            ctx.reset()
            ctx.performAndWait {
                if let messages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageId IN %@", ["random-message-id-123456"]), context: ctx), messages.count > 0 {
                    XCTAssertEqual(messages.first?.payload!["customPayload"] as! NSDictionary, self.userInfo["customPayload"] as! NSDictionary)
                    expectation?.fulfill()
                } else {
                    XCTFail("There should be some messages in database")
                }
            }
        }
        
        self.waitForExpectations(timeout: 60, handler: nil)
    }
}

class DefaultSharedDataStorageTests: XCTestCase {
    private let suiteName = "com.infobip.test.app-shared-storage"
    private let applicationCode = "test-app-code"
    private let containerURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        try! FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: containerURL)
        super.tearDown()
    }

    private func makeStorage() -> DefaultSharedDataStorage {
        DefaultSharedDataStorage(applicationCode: applicationCode, appGroupId: suiteName, containerURL: containerURL)!
    }

    private func makeMessage(_ id: String, alert: String = "Hello", reported: Bool = false) -> MM_MTMessage {
        MM_MTMessage(payload: ["messageId": id, "aps": ["alert": alert]],
                     deliveryMethod: .undefined,
                     seenDate: nil,
                     deliveryReportDate: nil,
                     seenStatus: .NotSeen,
                     isDeliveryReportSent: reported)!
    }

    func testCorruptArchiveIsReplacedByNextSave() throws {
        let storage = makeStorage()
        try Data("corrupt archive".utf8).write(to: storage.receiptFileURL)

        storage.save(message: makeMessage("recovered-message"))

        XCTAssertEqual(storage.drainMessages().map(\.messageId), ["recovered-message"])
    }

    func testReadFailureDoesNotOverwriteExistingReceipts() throws {
        let storage = makeStorage()
        storage.save(message: makeMessage("existing-message"))

        let originalPermissions = try FileManager.default.attributesOfItem(atPath: storage.receiptFileURL.path)[.posixPermissions] as? NSNumber
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: storage.receiptFileURL.path)
        defer {
            if let originalPermissions {
                try? FileManager.default.setAttributes([.posixPermissions: originalPermissions], ofItemAtPath: storage.receiptFileURL.path)
            }
        }
        guard (try? Data(contentsOf: storage.receiptFileURL)) == nil else {
            throw XCTSkip("The test process can still read files with their permissions removed")
        }

        storage.save(message: makeMessage("new-message"))
        try FileManager.default.setAttributes([.posixPermissions: originalPermissions ?? 0o600], ofItemAtPath: storage.receiptFileURL.path)

        XCTAssertEqual(storage.drainMessages().map(\.messageId), ["existing-message"])
    }

    func testInitDoesNotOverwriteExistingReceipts() throws {
        let writer = makeStorage()
        writer.save(message: makeMessage("existing-message"))
        let sizeBefore = try Data(contentsOf: writer.receiptFileURL).count

        let laterInstance = makeStorage()

        XCTAssertEqual(try Data(contentsOf: writer.receiptFileURL).count, sizeBefore)
        XCTAssertEqual(laterInstance.drainMessages().map(\.messageId), ["existing-message"])
    }

    func testMissingReceiptFileIsReadAsEmptyAndCreatedByFirstSave() {
        let storage = makeStorage()
        XCTAssertFalse(FileManager.default.fileExists(atPath: storage.receiptFileURL.path))
        XCTAssertTrue(storage.drainMessages().isEmpty)

        storage.save(message: makeMessage("first-message"))

        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.receiptFileURL.path))
        XCTAssertEqual(storage.drainMessages().map(\.messageId), ["first-message"])
    }

    func testMarkDeliveryReportedDistinguishesUpdatedAndConsumedReceipt() {
        let storage = makeStorage()
        storage.save(message: makeMessage("consumed-message"))

        let date = Date()
        XCTAssertEqual(storage.markDeliveryReported(messageId: "consumed-message", date: date), .updated)
        let consumedMessage = storage.drainMessages().first
        XCTAssertEqual(consumedMessage?.deliveryReportedDate, date)
        XCTAssertTrue(consumedMessage?.isDeliveryReportSent == true)

        XCTAssertEqual(storage.markDeliveryReported(messageId: "consumed-message", date: Date()), .receiptNotFound)
        XCTAssertTrue(storage.drainMessages().isEmpty)
    }

    func testSaveUpsertsSameMessageIdAndPreservesReportedStatus() {
        let storage = makeStorage()
        storage.save(message: makeMessage("same-id", alert: "first", reported: true))
        storage.save(message: makeMessage("same-id", alert: "updated"))

        let messages = storage.drainMessages()
        XCTAssertEqual(messages.map(\.messageId), ["same-id"])
        XCTAssertTrue(messages.first?.isDeliveryReportSent == true)
        XCTAssertEqual(messages.first?.originalPayload["aps"] as? NSDictionary, ["alert": "updated"] as NSDictionary)
        XCTAssertTrue(storage.drainMessages().isEmpty)
    }

    func testLegacyArchivedReceiptMigratesAndIsConsumed() throws {
        let legacyPayload: [String: Any] = ["messageId": "legacy-archive", "aps": ["alert": "Hello"]]
        let legacyMessages: [[String: Any]] = [["p": legacyPayload, "dlr": true, "dlrd": Date(timeIntervalSince1970: 123)]]
        let legacyData = try NSKeyedArchiver.archivedData(withRootObject: legacyMessages, requiringSecureCoding: true)
        UserDefaults(suiteName: suiteName)!.set(legacyData, forKey: applicationCode)

        let messages = makeStorage().drainMessages()

        XCTAssertEqual(messages.map(\.messageId), ["legacy-archive"])
        XCTAssertTrue(messages.first?.isDeliveryReportSent == true)
        XCTAssertNil(UserDefaults(suiteName: suiteName)!.object(forKey: applicationCode))
    }

    func testLegacyDictionaryArrayMigrates() {
        UserDefaults(suiteName: suiteName)!.set(
            [["p": ["messageId": "legacy-dictionary", "aps": ["alert": "Hello"]], "dlr": false]],
            forKey: applicationCode
        )

        let messages = makeStorage().drainMessages()

        XCTAssertEqual(messages.map(\.messageId), ["legacy-dictionary"])
        XCTAssertNil(UserDefaults(suiteName: suiteName)!.object(forKey: applicationCode))
    }

    func testConcurrentSavesDoNotLoseReceipts() {
        DispatchQueue.concurrentPerform(iterations: 20) { index in
            makeStorage().save(message: makeMessage("concurrent-\(index)"))
        }

        XCTAssertEqual(makeStorage().drainMessages().count, 20)
    }
}
