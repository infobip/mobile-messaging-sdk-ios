//
//  ApnsRegistrationManagerTests.swift
//  MobileMessagingExample
//
//  Created by Andrey Kadochnikov on 15/02/2018.
//

import XCTest
import Foundation
@testable import MobileMessaging

class ApnsRegistrationManagerMock: ApnsRegistrationManager {
	var _isRegistrationHealthy: Bool = false
	var deviceTokenUpdateWasCalled: Bool = false
	var regResetWasCalled: Bool = false
	var unregisterCalled: (() -> Void)? = nil
	var registerCalled: (() -> Void)? = nil
    
    override init(mmContext: MobileMessaging) {
        super.init(mmContext: mmContext)
        self.readyToRegisterForNotifications = true
    }
    
	override var isRegistrationHealthy: Bool {
		return _isRegistrationHealthy
	}
	
	override func setRegistrationIsHealthy() {
		_isRegistrationHealthy = true
	}
	
	override func cleanup() {
		_isRegistrationHealthy = false
	}
	
    override func updateDeviceToken(userInitiated: Bool, token: Data, completion: ((NSError?) -> Void)?) {
		deviceTokenUpdateWasCalled = true
		completion?(nil)
	}
	
	override func resetRegistration(userInitiated: Bool, completion: @escaping () -> Void) {
		regResetWasCalled = true
		setRegistrationIsHealthy()
		completion()
	}

	override func registerForRemoteNotifications(userInitiated: Bool) {
		registerCalled?()
	}

	override func unregister(userInitiated: Bool) {
		unregisterCalled?()
	}
}

class ApnsRegistrationManagerTests: MMTestCase {
	func testThatRegistrationResetLeadsToHealthyRegFlag() {
		weak var resetFinished = expectation(description: "regFinished")
		
		let mm = MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)!
		mm.doStart()
		let apnsManagerMock = ApnsRegistrationManagerMock(mmContext: mm)
		mm.pushServiceToken = "old token".mm_toHexademicalString
		mm.pushRegistrationId = "old push reg"
		mm.apnsRegistrationManager = apnsManagerMock
		
        mm.installationService.resetRegistration(userInitiated: false) { (err) in
			resetFinished?.fulfill()
		}
		
		self.waitForExpectations(timeout: 60, handler: { _ in
			XCTAssertTrue(mm.apnsRegistrationManager.isRegistrationHealthy)
			XCTAssertNil(MobileMessaging.getInstallation()?.pushServiceToken)
			XCTAssertNil(MobileMessaging.getInstallation()?.pushRegistrationId)
		})
	}
	
	func testThatVeryFirstDeviceTokenLeadsToHealthyRegAndTokenUpdate() {
		weak var regFinished = expectation(description: "regFinished")
		        
        let mm = MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)!
        mm.doStart()
        XCTAssertNil(mm.pushServiceToken)
		let apnsManagerMock = ApnsRegistrationManagerMock(mmContext: mm)
		
		mm.apnsRegistrationManager = apnsManagerMock
		
		mm.apnsRegistrationManager.didRegisterForRemoteNotificationsWithDeviceToken(userInitiated: false, token: "very first token".data(using: String.Encoding.utf16)!) { (err) in
			XCTAssertTrue(mm.apnsRegistrationManager.isRegistrationHealthy)
			regFinished?.fulfill()
		}
		
		self.waitForExpectations(timeout: 60, handler: { _ in
			XCTAssertTrue(mm.apnsRegistrationManager.isRegistrationHealthy)
			XCTAssertTrue(apnsManagerMock.deviceTokenUpdateWasCalled)
			XCTAssertFalse(apnsManagerMock.regResetWasCalled)
		})
	}
	
	func testThatSameDeviceTokenLeadsToHealthyReg() {
		weak var regFinished = expectation(description: "regFinished")
		
		let mm = MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)!
		mm.doStart()
		let apnsManagerMock = ApnsRegistrationManagerMock(mmContext: mm)
		mm.apnsRegistrationManager = apnsManagerMock
		mm.pushServiceToken = "same token".mm_toHexademicalString
		mm.pushRegistrationId = "some push reg"
        mm.apnsRegistrationManager.didRegisterForRemoteNotificationsWithDeviceToken(userInitiated: false, token: "same token".data(using: String.Encoding.utf16)!) { (err) in
			XCTAssertTrue(mm.apnsRegistrationManager.isRegistrationHealthy)
			regFinished?.fulfill()
		}
		
		self.waitForExpectations(timeout: 60, handler: { _ in
			XCTAssertTrue(mm.apnsRegistrationManager.isRegistrationHealthy)
			XCTAssertTrue(apnsManagerMock.deviceTokenUpdateWasCalled)
			XCTAssertFalse(apnsManagerMock.regResetWasCalled)
		})
	}
	
	func testBackupRestorationCaseLeadsToHealedRegistration() {
		weak var regFinished = expectation(description: "regFinished")
		
		let mm = MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)!
		mm.doStart()
		let apnsManagerMock = ApnsRegistrationManagerMock(mmContext: mm)
		mm.pushServiceToken = "old token".mm_toHexademicalString
		mm.pushRegistrationId = "old push reg"
		mm.apnsRegistrationManager = apnsManagerMock
		
		
        mm.apnsRegistrationManager.didRegisterForRemoteNotificationsWithDeviceToken(userInitiated: false, token: "actual token".data(using: String.Encoding.utf16)!) { (err) in
			regFinished?.fulfill()
		}
		
		self.waitForExpectations(timeout: 60, handler: { _ in
			XCTAssertTrue(mm.apnsRegistrationManager.isRegistrationHealthy)
			XCTAssertTrue(apnsManagerMock.deviceTokenUpdateWasCalled)
			XCTAssertTrue(apnsManagerMock.regResetWasCalled)
		})
	}
}
 
