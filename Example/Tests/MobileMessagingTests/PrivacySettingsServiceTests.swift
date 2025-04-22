//
//  PrivacySettingsServiceTests.swift
//  MobileMessagingExample
//
//  Created by Andrey Kadochnikov on 17.04.2025.
//

import XCTest
import Foundation
@testable import MobileMessaging

class PrivacySettingsServiceTests: MMTestCase {
    func testThatUserDataMustBeWipedAfterRestart() {
        MMTestCase.startWithCorrectApplicationCode()
        
        let currentUser = MobileMessaging.getUser()!
        currentUser.lastName = "Skywalker"
        currentUser.gender = .Male
        currentUser.emails = ["luke@starwars.com"]
        currentUser.phones = ["123"]
        currentUser.externalUserId = "123"
        currentUser.customAttributes = ["home": "Death Star" as NSString]
        currentUser.archiveAll()
    
        MobileMessaging.sharedInstance?.doStop()
        
        MobileMessaging.privacySettings.userDataPersistingDisabled = true
        
        MMTestCase.startWithCorrectApplicationCode()
        
        waitForExpectations(timeout: 20) { _ in
            let dirtyUserData = self.retrieveDataFromPath(MMUser.dirtyPath)!
            let dirtyUser = try! NSKeyedUnarchiver.unarchivedObject(ofClass: MMUser.self, from: dirtyUserData)
            self.assertUserSensitiveDataNils(user: dirtyUser!)
            
            let currentUserData = self.retrieveDataFromPath(MMUser.currentPath)!
            let currentUser = try! NSKeyedUnarchiver.unarchivedObject(ofClass: MMUser.self, from: currentUserData)
            self.assertUserSensitiveDataNils(user: currentUser!)
        }
    }
    
    func testThatUserDataMustBeWipedInRuntime() {
        MMTestCase.startWithCorrectApplicationCode()
        
        let currentUser = MobileMessaging.getUser()!
        currentUser.lastName = "Skywalker"
        currentUser.gender = .Male
        currentUser.emails = ["luke@starwars.com"]
        currentUser.phones = ["123"]
        currentUser.externalUserId = "123"
        currentUser.customAttributes = ["home": "Death Star" as NSString]
        currentUser.archiveAll()

        MobileMessaging.privacySettings.userDataPersistingDisabled = true
        
        waitForExpectations(timeout: 20) { _ in
            let dirtyUserData = self.retrieveDataFromPath(MMUser.dirtyPath)!
            let dirtyUser = try! NSKeyedUnarchiver.unarchivedObject(ofClass: MMUser.self, from: dirtyUserData)
            self.assertUserSensitiveDataNils(user: dirtyUser!)
            
            let currentUserData = self.retrieveDataFromPath(MMUser.currentPath)!
            let currentUser = try! NSKeyedUnarchiver.unarchivedObject(ofClass: MMUser.self, from: currentUserData)
            self.assertUserSensitiveDataNils(user: currentUser!)
        }
    }
    
    func testThatInstallationDataMustBeWipedAfterRestart() {
        MMTestCase.startWithCorrectApplicationCode()
        
        let currentInstallation = MobileMessaging.getInstallation()!
        currentInstallation.applicationUserId = "applicationUserId"
        currentInstallation.appVersion = "1.0"
        currentInstallation.customAttributes = ["deviceColor":"red" as NSString]
        currentInstallation.deviceManufacturer = "Apple"
        currentInstallation.deviceModel = "iPhone"
        currentInstallation.deviceName = "16 Pro Max"
        currentInstallation.deviceTimeZone = "ZG"
        currentInstallation.language = "EN"
        currentInstallation.os = "iOS"
        currentInstallation.osVersion = "13"
        currentInstallation.pushRegistrationId = "pushRegistrationId"
        currentInstallation.pushServiceToken = "pushServiceToken"
        currentInstallation.pushServiceType = "APNS"
        currentInstallation.sdkVersion = "1.0"
        currentInstallation.archiveAll()
    
        MobileMessaging.sharedInstance?.doStop()
        
        MobileMessaging.privacySettings.installationDataPersistingDisabled = true
        
        MMTestCase.startWithCorrectApplicationCode()
        
        waitForExpectations(timeout: 20) { _ in
            let dirtyInstallationData = self.retrieveDataFromPath(MMInstallation.dirtyPath)!
            let dirtyInstallation = try! NSKeyedUnarchiver.unarchivedObject(ofClass: MMInstallation.self, from: dirtyInstallationData)
            self.assertInstallatonSensitiveDataNils(installation: dirtyInstallation!)
            
            let currentInstallationData = self.retrieveDataFromPath(MMInstallation.currentPath)!
            let currentInstallation = try! NSKeyedUnarchiver.unarchivedObject(ofClass: MMInstallation.self, from: currentInstallationData)
            self.assertInstallatonSensitiveDataNils(installation: currentInstallation!)
        }
    }
    
    func testThatInstallationDataMustBeWipedInRuntime() {
        MMTestCase.startWithCorrectApplicationCode()
        
        let currentInstallation = MobileMessaging.getInstallation()!
        currentInstallation.applicationUserId = "applicationUserId"
        currentInstallation.appVersion = "1.0"
        currentInstallation.customAttributes = ["deviceColor":"red" as NSString]
        currentInstallation.deviceManufacturer = "Apple"
        currentInstallation.deviceModel = "iPhone"
        currentInstallation.deviceName = "16 Pro Max"
        currentInstallation.deviceTimeZone = "ZG"
        currentInstallation.language = "EN"
        currentInstallation.os = "iOS"
        currentInstallation.osVersion = "13"
        currentInstallation.pushRegistrationId = "pushRegistrationId"
        currentInstallation.pushServiceToken = "pushServiceToken"
        currentInstallation.pushServiceType = "APNS"
        currentInstallation.sdkVersion = "1.0"
        currentInstallation.archiveAll()
        
        MobileMessaging.privacySettings.installationDataPersistingDisabled = true
        
        waitForExpectations(timeout: 20) { _ in
            let dirtyInstallationData = self.retrieveDataFromPath(MMInstallation.dirtyPath)!
            let dirtyInstallation = try! NSKeyedUnarchiver.unarchivedObject(ofClass: MMInstallation.self, from: dirtyInstallationData)
            self.assertInstallatonSensitiveDataNils(installation: dirtyInstallation!)
            
            let currentInstallationData = self.retrieveDataFromPath(MMInstallation.currentPath)!
            let currentInstallation = try! NSKeyedUnarchiver.unarchivedObject(ofClass: MMInstallation.self, from: currentInstallationData)
            self.assertInstallatonSensitiveDataNils(installation: currentInstallation!)
        }
    }
    
    func testThatAppCodeMustBeWipedInRuntime() {
        MMTestCase.startWithCorrectApplicationCode()
        
        let internalDataData = self.retrieveDataFromPath(InternalData.currentPath)!
        let internalData = try! NSKeyedUnarchiver.unarchivedObject(ofClass: InternalData.self, from: internalDataData)!
        XCTAssertNotNil(internalData.applicationCode)
    
        MobileMessaging.privacySettings.applicationCodePersistingDisabled = true
        
        waitForExpectations(timeout: 20) { _ in
            let internalDataData = self.retrieveDataFromPath(InternalData.currentPath)!
            let internalData = try! NSKeyedUnarchiver.unarchivedObject(ofClass: InternalData.self, from: internalDataData)!
            XCTAssertNil(internalData.applicationCode)
        }
    }
    
    func testThatAppCodeMustBeWipedAfterRestart() {
        MMTestCase.startWithCorrectApplicationCode()
        
        let internalDataData = self.retrieveDataFromPath(InternalData.currentPath)!
        let internalData = try! NSKeyedUnarchiver.unarchivedObject(ofClass: InternalData.self, from: internalDataData)!
        XCTAssertNotNil(internalData.applicationCode)
        
        MobileMessaging.sharedInstance?.doStop()
        
        MobileMessaging.privacySettings.applicationCodePersistingDisabled = true
        
        MMTestCase.startWithCorrectApplicationCode()
        
        waitForExpectations(timeout: 20) { _ in
            let internalDataData = self.retrieveDataFromPath(InternalData.currentPath)!
            let internalData = try! NSKeyedUnarchiver.unarchivedObject(ofClass: InternalData.self, from: internalDataData)!
            XCTAssertNil(internalData.applicationCode)
        }
    }
    
    private func assertUserSensitiveDataNils(user: MMUser) {
        XCTAssertNil(user.externalUserId, "userdata must not be persisted")
        XCTAssertNil(user.firstName, "userdata must not be persisted")
        XCTAssertNil(user.middleName, "userdata must not be persisted")
        XCTAssertNil(user.lastName, "userdata must not be persisted")
        XCTAssertNil(user.phones, "userdata must not be persisted")
        XCTAssertNil(user.emails, "userdata must not be persisted")
        XCTAssertNil(user.tags, "userdata must not be persisted")
        XCTAssertNil(user.gender, "userdata must not be persisted")
        XCTAssertNil(user.birthday, "userdata must not be persisted")
        XCTAssertNil(user.customAttributes, "userdata must not be persisted")
        XCTAssertNil(user.installations, "userdata must not be persisted")
    }
    
    private func assertInstallatonSensitiveDataNils(installation: MMInstallation) {
        XCTAssertNil(installation.applicationUserId, "installation sensitive data must not be persisted")
        XCTAssertNil(installation.appVersion, "installation sensitive data must not be persisted")
        XCTAssertTrue(installation.customAttributes.count == 0, "installation sensitive data")
        XCTAssertNil(installation.deviceManufacturer, "installation sensitive data must not be persisted")
        XCTAssertNil(installation.deviceModel, "installation sensitive data must not be persisted")
        XCTAssertNil(installation.deviceName, "installation sensitive data must not be persisted")
        XCTAssertNil(installation.deviceTimeZone, "installation sensitive data must not be persisted")
        XCTAssertNil(installation.language, "installation sensitive data must not be persisted")
        XCTAssertNil(installation.os, "installation sensitive data must not be persisted")
        XCTAssertNil(installation.osVersion, "installation sensitive data must not be persisted")
        XCTAssertNil(installation.sdkVersion, "installation sensitive data must not be persisted")
    }
    
    private func retrieveDataFromPath(_ path: String) -> Data? {
        let url = URL(fileURLWithPath: path)
        return try? Data(contentsOf: url)
    }
}
