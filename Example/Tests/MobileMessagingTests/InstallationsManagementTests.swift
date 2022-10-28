//
//  InstallationsManagementTests.swift
//  MobileMessagingExample
//
//  Created by Andrey Kadochnikov on 17/12/2018.
//
//

import Foundation
import XCTest
@testable import MobileMessaging

class InstallationsManagementTests: MMTestCase {
	
	func testThatSettingPrimaryOtherInstallationReturnsProperInstallations() {
        MMTestCase.startWithCorrectApplicationCode()
        
		weak var managementFinished = expectation(description: "managementFinished")
		mobileMessagingInstance.pushRegistrationId = "pr-0"

		let currentUser = MobileMessaging.getUser()!
		currentUser.installations = [
			MMInstallation(applicationUserId: nil, appVersion: nil, customAttributes: [:], deviceManufacturer: "Apple", deviceModel: "iPhone", deviceName: "iphone", deviceSecure: false, deviceTimeZone: nil, geoEnabled: false, isPrimaryDevice: true, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: "iOS", osVersion: "1.2", pushRegistrationId: "pr-0", pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil),
            MMInstallation(applicationUserId: nil, appVersion: nil, customAttributes: [:], deviceManufacturer: "Apple", deviceModel: "iPhone", deviceName: "Jo I", deviceSecure: false, deviceTimeZone: nil, geoEnabled: false, isPrimaryDevice: false, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: "iOS", osVersion: "2.2", pushRegistrationId: "pr-1", pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil),
            MMInstallation(applicationUserId: nil, appVersion: nil, customAttributes: [:], deviceManufacturer: "Samsung", deviceModel: "Galaxy", deviceName: "Jo S", deviceSecure: false, deviceTimeZone: nil, geoEnabled: false, isPrimaryDevice: false, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: "Android", osVersion: "3.1", pushRegistrationId: "pr-2", pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil),
            MMInstallation(applicationUserId: nil, appVersion: nil, customAttributes: [:], deviceManufacturer: "Xiaomi", deviceModel: "Mi 8", deviceName: "Jo M", deviceSecure: false, deviceTimeZone: nil, geoEnabled: false, isPrimaryDevice: false, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: "Android", osVersion: "1.2.2", pushRegistrationId: "pr-3", pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil)
		]
		currentUser.archiveAll()

        mobileMessagingInstance.httpSessionManager = SessionManagerSuccessMock(responseJson: { req in
			if req is PatchInstance {
				return JSON()
			} else {
				return JSON()
			}
		})

		MobileMessaging.setInstallation(withPushRegistrationId: "pr-1", asPrimary: true, completion: { (installations, error) in

			do {
				let newPrimary = installations!.first(where: { $0.isPrimaryDevice })!
				XCTAssertEqual(newPrimary.pushRegistrationId, "pr-1")

				let oldPrimary = installations!.first(where: { $0.pushRegistrationId == "pr-0" })!
				XCTAssertFalse(oldPrimary.isPrimaryDevice)
			}
			do {
				let newPrimary = currentUser.installations!.first(where: { $0.isPrimaryDevice })!
				XCTAssertEqual(newPrimary.pushRegistrationId, "pr-1")

				let oldPrimary = currentUser.installations!.first(where: { $0.pushRegistrationId == "pr-0" })!
				XCTAssertFalse(oldPrimary.isPrimaryDevice)
			}



			XCTAssertNil(MMUser.delta?["instances"])
			managementFinished?.fulfill()
		})

		waitForExpectations(timeout: 20) { _ in }
	}

	func testThatLogoutOtherInstallationReturnsProperInstallations() {
        MMTestCase.startWithCorrectApplicationCode()
        
		weak var managementFinished = expectation(description: "managementFinished")
		let currentUser = MobileMessaging.getUser()!
		mobileMessagingInstance.pushRegistrationId = "pr-0"
		currentUser.installations = [
            MMInstallation(applicationUserId: nil, appVersion: nil, customAttributes: [:], deviceManufacturer: "Apple", deviceModel: "iPhone", deviceName: "iphone", deviceSecure: false, deviceTimeZone: nil, geoEnabled: false, isPrimaryDevice: true, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: "iOS", osVersion: "1.2", pushRegistrationId: "pr-0", pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil),
            MMInstallation(applicationUserId: nil, appVersion: nil, customAttributes: [:], deviceManufacturer: "Apple", deviceModel: "iPhone", deviceName: "Jo I", deviceSecure: false, deviceTimeZone: nil, geoEnabled: false, isPrimaryDevice: false, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: "iOS", osVersion: "2.2", pushRegistrationId: "pr-1", pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil),
            MMInstallation(applicationUserId: nil, appVersion: nil, customAttributes: [:], deviceManufacturer: "Samsung", deviceModel: "Galaxy", deviceName: "Jo S", deviceSecure: false, deviceTimeZone: nil, geoEnabled: false, isPrimaryDevice: false, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: "Android", osVersion: "3.1", pushRegistrationId: "pr-2", pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil),
            MMInstallation(applicationUserId: nil, appVersion: nil, customAttributes: [:], deviceManufacturer: "Xiaomi", deviceModel: "Mi 8", deviceName: "Jo M", deviceSecure: false, deviceTimeZone: nil, geoEnabled: false, isPrimaryDevice: false, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: "Android", osVersion: "1.2.2", pushRegistrationId: "pr-3", pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil)
		]
		currentUser.archiveAll()

        mobileMessagingInstance.httpSessionManager = SessionManagerSuccessMock(responseJson: { req in
			if req is PostInstance {
				return JSON()
			} else {
				return JSON()
			}
		})

        mobileMessagingInstance.userService.depersonalizeInstallation(userInitiated: true, withPushRegistrationId: "pr-1", completion: { (installations, error) in
			XCTAssertEqual(installations?.count, 3)
			XCTAssertNil(installations?.first(where: { $0.pushRegistrationId == "pr-1"} ))
			
			XCTAssertNil(MMUser.delta?["instances"])
			managementFinished?.fulfill()
		})

		waitForExpectations(timeout: 20) { _ in }
	}
}
