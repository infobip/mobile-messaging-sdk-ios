//
//  ApnsRegistrationManagerTests.swift
//  MobileMessagingExample
//
//  Created by Andrey Kadochnikov on 15/02/2018.
//

import XCTest
import Foundation
@testable import MobileMessaging

class ApnsRegistrationManagerTests: MMTestCase {
	func testThatRegistrationResetLeadsToHealthyRegFlag() {
		weak var resetFinished = expectation(description: "regFinished")
		
		MMTestCase.cleanUpAndStop()
		
		let mm = MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)!
		mm.start()
		let apnsManagerMock = ApnsRegistrationManagerMock(mmContext: mm)
		mm.pushServiceToken = "old token".mm_toHexademicalString
		mm.pushRegistrationId = "old push reg"
		mm.apnsRegistrationManager = apnsManagerMock
		
		mm.installationService.resetRegistration { (err) in
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
		
		MMTestCase.cleanUpAndStop()
		
		let mm = MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)!
		mm.start()
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
		mm.start()
		let apnsManagerMock = ApnsRegistrationManagerMock(mmContext: mm)
		mm.apnsRegistrationManager = apnsManagerMock
		mm.pushServiceToken = "same token".mm_toHexademicalString
		mm.pushRegistrationId = "some push reg"
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
		mm.start()
		let apnsManagerMock = ApnsRegistrationManagerMock(mmContext: mm)
		mm.pushServiceToken = "old token".mm_toHexademicalString
		mm.pushRegistrationId = "old push reg"
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
 
