//
//  InstallationDataServiceTests.swift
//  MobileMessaging
//
//  Created by Luka Ilić on 02/09/25.
//

import XCTest
@testable import MobileMessaging

class InstallationDataServiceTests: MMTestCase {
    
    var installationService: InstallationDataService!
    
    override class func setUp() {
        UserDefaults.standard.removeObject(forKey: Consts.UserDefaultsKeys.universalInstallationId)
        if let sharedDefaults = UserDefaults(suiteName: Bundle.mainAppBundle.appGroupId) {
            sharedDefaults.removeObject(forKey: Consts.UserDefaultsKeys.universalInstallationId)
        }
    }
    
    override class func tearDown() {
        UserDefaults.standard.removeObject(forKey: Consts.UserDefaultsKeys.universalInstallationId)
        if let sharedDefaults = UserDefaults(suiteName: Bundle.mainAppBundle.appGroupId) {
            sharedDefaults.removeObject(forKey: Consts.UserDefaultsKeys.universalInstallationId)
        }
    }
    
    func testGetUniversalInstallationId_GeneratesNewId_WhenNoneExists() {
        MMTestCase.startWithCorrectApplicationCode()
        installationService = mobileMessagingInstance.installationService
        
        let installationId = installationService.getUniversalInstallationId()
        
        XCTAssertFalse(installationId.isEmpty)
        XCTAssertTrue(UUID(uuidString: installationId) != nil, "Should be a valid UUID")
        
        if let appGroupId = Bundle.mainAppBundle.appGroupId,
           let sharedDefaults = UserDefaults(suiteName: appGroupId) {
            let storedId = sharedDefaults.string(forKey: Consts.UserDefaultsKeys.universalInstallationId)
            XCTAssertEqual(installationId, storedId)
        } else {
            let storedId = UserDefaults.standard.string(forKey: Consts.UserDefaultsKeys.universalInstallationId)
            XCTAssertEqual(installationId, storedId)
        }
    }
    
    func testGetUniversalInstallationId_MigratesFromStandardUserDefaults() {
        let expectedId = "migration-test-id-456"
        UserDefaults.standard.set(expectedId, forKey: Consts.UserDefaultsKeys.universalInstallationId)
        
        if let appGroupId = Bundle.mainAppBundle.appGroupId,
           let sharedDefaults = UserDefaults(suiteName: appGroupId) {
            sharedDefaults.removeObject(forKey: Consts.UserDefaultsKeys.universalInstallationId)
        }
        
        // migration should happen during service start
        MMTestCase.startWithCorrectApplicationCode()
        installationService = mobileMessagingInstance.installationService
        
        let installationId = installationService.getUniversalInstallationId()
        
        XCTAssertEqual(installationId, expectedId)
        
        if let appGroupId = Bundle.mainAppBundle.appGroupId,
           let sharedDefaults = UserDefaults(suiteName: appGroupId) {
            let migratedId = sharedDefaults.string(forKey: Consts.UserDefaultsKeys.universalInstallationId)
            XCTAssertEqual(migratedId, expectedId, "Should migrate to shared UserDefaults during service start")
        }
    }
    
    func testGetUniversalInstallationId_ConsistentResults() {
        MMTestCase.startWithCorrectApplicationCode()
        installationService = mobileMessagingInstance.installationService
        
        let firstCall = installationService.getUniversalInstallationId()
        let secondCall = installationService.getUniversalInstallationId()
        let thirdCall = installationService.getUniversalInstallationId()
        
        XCTAssertEqual(firstCall, secondCall)
        XCTAssertEqual(secondCall, thirdCall)
        XCTAssertFalse(firstCall.isEmpty)
        XCTAssertTrue(UUID(uuidString: firstCall) != nil, "Should be a valid UUID")
    }
    
    func testGetUniversalInstallationId_UsesSharedUserDefaults_WhenAvailable() {
        MMTestCase.startWithCorrectApplicationCode()
        installationService = mobileMessagingInstance.installationService
        
        let sharedId = "shared-installation-id"
        let standardId = "standard-installation-id"
        
        UserDefaults.standard.set(standardId, forKey: Consts.UserDefaultsKeys.universalInstallationId)
        
        if let sharedDefaults = UserDefaults(suiteName: Bundle.mainAppBundle.appGroupId) {
            sharedDefaults.set(sharedId, forKey: Consts.UserDefaultsKeys.universalInstallationId)
            
            let installationId = installationService.getUniversalInstallationId()
            
            XCTAssertEqual(installationId, sharedId)
        } else {
            let installationId = installationService.getUniversalInstallationId()
            XCTAssertEqual(installationId, standardId)
        }
    }
    
    func testPerformInstallationIdMigration_MigratesWhenNeeded() {
        MMTestCase.startWithCorrectApplicationCode()
        installationService = mobileMessagingInstance.installationService
        
        let testId = "direct-migration-test-id"
        
        UserDefaults.standard.set(testId, forKey: Consts.UserDefaultsKeys.universalInstallationId)
        if let appGroupId = Bundle.mainAppBundle.appGroupId,
           let sharedDefaults = UserDefaults(suiteName: appGroupId) {
            sharedDefaults.removeObject(forKey: Consts.UserDefaultsKeys.universalInstallationId)
        }
        
        installationService.performInstallationIdMigration()
        
        if let appGroupId = Bundle.mainAppBundle.appGroupId,
           let sharedDefaults = UserDefaults(suiteName: appGroupId) {
            let migratedId = sharedDefaults.string(forKey: Consts.UserDefaultsKeys.universalInstallationId)
            XCTAssertEqual(migratedId, testId, "Migration method should move ID to shared UserDefaults")
        } else {
            XCTAssert(true, "Skipping migration test - no App Group available")
        }
    }
    
    func testPerformInstallationIdMigration_SkipsWhenAlreadyMigrated() {
        MMTestCase.startWithCorrectApplicationCode()
        installationService = mobileMessagingInstance.installationService
        
        if let appGroupId = Bundle.mainAppBundle.appGroupId,
           let sharedDefaults = UserDefaults(suiteName: appGroupId) {
            
            let existingSharedId = "existing-shared-id"
            let standardId = "standard-id-should-not-overwrite"
            
            sharedDefaults.set(existingSharedId, forKey: Consts.UserDefaultsKeys.universalInstallationId)
            UserDefaults.standard.set(standardId, forKey: Consts.UserDefaultsKeys.universalInstallationId)
            
            installationService.performInstallationIdMigration()
            
            let finalSharedId = sharedDefaults.string(forKey: Consts.UserDefaultsKeys.universalInstallationId)
            XCTAssertEqual(finalSharedId, existingSharedId, "Migration should not overwrite existing shared UserDefaults value")
        } else {
            XCTAssert(true, "Skipping migration test - no App Group available")
        }
    }
}
