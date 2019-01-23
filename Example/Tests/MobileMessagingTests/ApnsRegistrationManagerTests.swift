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

	override var isRegistrationHealthy: Bool {
		return _isRegistrationHealthy
	}
	
	override func setRegistrationIsHealthy() {
		_isRegistrationHealthy = true
	}
	
	override func cleanup() {
		_isRegistrationHealthy = false
	}
	
	override func updateDeviceToken(_ token: Data, completion: ((NSError?) -> Void)?) {
		deviceTokenUpdateWasCalled = true
		completion?(nil)
	}
	
	override func resetRegistration(completion: @escaping () -> Void) {
		regResetWasCalled = true
		setRegistrationIsHealthy()
		completion()
	}

	override func registerForRemoteNotifications() {
		registerCalled?()
	}

	override func unregister() {
		unregisterCalled?()
	}
}

class ApnsRegistrationManagerTests: MMTestCase {
	func testThatRegistrationResetLeadsToHealthyRegFlag() {
		weak var resetFinished = expectation(description: "regFinished")
		
		MMTestCase.cleanUpAndStop()
		
		let mm = MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)!
		let apnsManagerMock = ApnsRegistrationManagerMock(mmContext: mm)
		mm.currentInstallation.deviceToken = "old token".mm_toHexademicalString
		mm.currentInstallation.pushRegistrationId = "old push reg"
		mm.apnsRegistrationManager = apnsManagerMock
		
		mm.currentInstallation.resetRegistration { (err) in
			resetFinished?.fulfill()
		}
		
		self.waitForExpectations(timeout: 60, handler: { _ in
			XCTAssertTrue(mm.apnsRegistrationManager.isRegistrationHealthy)
			XCTAssertNil(mm.currentInstallation.deviceToken)
			XCTAssertNil(mm.currentInstallation.pushRegistrationId)
		})
	}
	
	func testThatVeryFirstDeviceTokenLeadsToHealthyRegAndTokenUpdate() {
		weak var regFinished = expectation(description: "regFinished")
		
		MMTestCase.cleanUpAndStop()
		
		let mm = MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)!
		let apnsManagerMock = ApnsRegistrationManagerMock(mmContext: mm)
		
		mm.apnsRegistrationManager = apnsManagerMock
		
		mm.apnsRegistrationManager.didRegisterForRemoteNotificationsWithDeviceToken("very first token".data(using: String.Encoding.utf16)!) { (err) in
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
		
		MMTestCase.cleanUpAndStop()
		
		let mm = MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)!
		let apnsManagerMock = ApnsRegistrationManagerMock(mmContext: mm)
		mm.apnsRegistrationManager = apnsManagerMock
		mm.currentInstallation.deviceToken = "same token".mm_toHexademicalString
		mm.currentInstallation.pushRegistrationId = "some push reg"
		mm.apnsRegistrationManager.didRegisterForRemoteNotificationsWithDeviceToken("same token".data(using: String.Encoding.utf16)!) { (err) in
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
		
		MMTestCase.cleanUpAndStop()
		
		let mm = MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)!
		let apnsManagerMock = ApnsRegistrationManagerMock(mmContext: mm)
		mm.currentInstallation.deviceToken = "old token".mm_toHexademicalString
		mm.currentInstallation.pushRegistrationId = "old push reg"
		mm.apnsRegistrationManager = apnsManagerMock
		
		
		mm.apnsRegistrationManager.didRegisterForRemoteNotificationsWithDeviceToken("actual token".data(using: String.Encoding.utf16)!) { (err) in
			regFinished?.fulfill()
		}
		
		self.waitForExpectations(timeout: 60, handler: { _ in
			XCTAssertTrue(mm.apnsRegistrationManager.isRegistrationHealthy)
			XCTAssertTrue(apnsManagerMock.deviceTokenUpdateWasCalled)
			XCTAssertTrue(apnsManagerMock.regResetWasCalled)
		})
	}
}
 
