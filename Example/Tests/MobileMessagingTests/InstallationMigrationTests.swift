//
//  InstallationMigrationTests.swift
//  MobileMessagingExample_Tests
//
//  Created by Andrey Kadochnikov on 07/11/2018.
//

import XCTest
import CoreData
import CoreLocation
@testable import MobileMessaging

class InstallationMigrationTests: XCTestCase {

	func testDataModel_Migration_0_3() {

        MobileMessaging.doCleanUp(false)

		do {
			let storage = makeStorageForModel(at: "MMInternalStorageModel.momd/MMStorageModel_0")
			let mm = initMmWithStorage(storage)
			let coreDataProvider: CoreDataProvider = CoreDataProvider(storage: mm.internalStorage)
			coreDataProvider.context.performAndWait {
				coreDataProvider.installationObject.setValue(["firstName": "Darth",
																 "middleName": "_",
																 "lastName": "Vader",
																 "birthdate": "1980-12-12",
																 "gender": "M",
																 "msisdn": "79214444444",
																 "email": "darth@vader.com"], forKey: "predefinedUserData")
				coreDataProvider.installationObject.setValue("pushRegId", forKey: "internalUserId")
				coreDataProvider.installationObject.setValue("extUserId", forKey: "externalUserId")
				coreDataProvider.installationObject.setValue(13, forKey: "badgeNumber")
				coreDataProvider.installationObject.setValue("device_token", forKey: "deviceToken")
				coreDataProvider.installationObject.setValue(["home": "tatooine"], forKey: "customUserData")
				coreDataProvider.installationObject.setValue(123, forKey: "systemDataHash")
				coreDataProvider.installationObject.setValue(CLLocation(latitude: 44.86803631018752, longitude: 13.84586334228516), forKey: "location")
				coreDataProvider.installationObject.setValue(true, forKey: "isRegistrationEnabled")
				coreDataProvider.installationObject.setValue(true, forKey: "isPrimaryDevice")
				coreDataProvider.installationObject.setValue(2, forKey: "logoutStatusValue")
				coreDataProvider.installationObject.setValue(3, forKey: "logoutFailCounter")
			}

			coreDataProvider.context.MM_saveToPersistentStoreAndWait()


			XCTAssertEqual("extUserId", coreDataProvider.installationObject.value(forKey: "externalUserId") as! String)
			// ...
			XCTAssertEqual("pushRegId", coreDataProvider.installationObject.value(forKey: "internalUserId") as! String)
			XCTAssertEqual(["firstName": "Darth",
							"middleName": "_",
							"lastName": "Vader",
							"birthdate": "1980-12-12",
							"gender": "M",
							"msisdn": "79214444444",
							"email": "darth@vader.com"], coreDataProvider.installationObject.value(forKey: "predefinedUserData") as! Dictionary)

            MobileMessaging.sharedInstance?.doStop()
			MobileMessaging.sharedInstance = nil
		}
		do {
			
			let storage = makeStorageForModel(at: "MMInternalStorageModel.momd/MMStorageModel_3")
			let mm = initMmWithStorage(storage)

			let installation = mm.resolveInstallation()
			let user = mm.resolveUser()
			let internalData = mm.internalData()


			XCTAssertEqual(user.firstName, "Darth")
			XCTAssertEqual(user.middleName, "_")
			XCTAssertEqual(user.lastName, "Vader")
			XCTAssertEqual(user.birthday, darthVaderDateOfBirth)
			XCTAssertEqual(user.gender, .Male)
			XCTAssertEqual(user.phones, ["79214444444"])
			XCTAssertEqual(user.emails!.first, "darth@vader.com")
			XCTAssertEqual(user.externalUserId, "extUserId")
			XCTAssertEqual(user.customAttributes as! Dictionary, ["home": "tatooine"])
			XCTAssertEqual(user.tags, nil)
			XCTAssertEqual(user.installations, nil)

			XCTAssertEqual(installation.pushRegistrationId, "pushRegId")
			XCTAssertEqual(installation.applicationUserId, nil)

			XCTAssertEqual(installation.pushServiceToken, "device_token")
			XCTAssertEqual(installation.isPushRegistrationEnabled, true)
			XCTAssertEqual(installation.isPrimaryDevice, true)

			XCTAssertEqual(internalData.badgeNumber, 13)
			XCTAssertEqual(internalData.systemDataHash, 123)
			XCTAssertNotNil(internalData.location)
			XCTAssertEqual(internalData.currentDepersonalizationStatus, .success)
			XCTAssertEqual(internalData.depersonalizeFailCounter, 3)



            MobileMessaging.sharedInstance?.doStop()
			MobileMessaging.sharedInstance = nil
		}
	}

	func testDataModel_Migration_2_3() {
        
        MobileMessaging.doCleanUp(false)

		let instance = MMInstallation(applicationUserId: "applicationUserId", appVersion: nil, customAttributes: ["foo": "bar" as MMAttributeType], deviceManufacturer: nil, deviceModel: nil, deviceName: nil, deviceSecure: false, deviceTimeZone: nil, geoEnabled: false, isPrimaryDevice: true, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: nil, os: nil, osVersion: nil, pushRegistrationId: "pushRegistrationId", pushServiceToken: "pushServiceToken", pushServiceType: nil, sdkVersion: nil)
		do {
			let storage = makeStorageForModel(at: "MMInternalStorageModel.momd/MMStorageModel_2")
			let mm = initMmWithStorage(storage)
			let coreDataProvider: CoreDataProvider = CoreDataProvider(storage: mm.internalStorage)
			coreDataProvider.context.performAndWait {

				let i = coreDataProvider.installationObject
				i.setValue("Darth", forKey: "firstName")
				i.setValue("_", forKey: "middleName")
				i.setValue("Vader", forKey: "lastName")
				i.setValue("1980-12-12", forKey: "birthday")
				i.setValue("Male", forKey: "gender")
				i.setValue([MMPhone(number: "79214444444", preferred: false)], forKey: "phones")
				i.setValue([MMEmail(address: "darth@vader.com", preferred: false)], forKey: "emails")
				i.setValue("pushRegId", forKey: "pushRegId")
				i.setValue("extUserId", forKey: "externalUserId")
				i.setValue("applicationUserId", forKey: "applicationUserId")
				i.setValue(13, forKey: "badgeNumber")
				i.setValue("device_token", forKey: "pushServiceToken")
				i.setValue(["home": "tatooine"], forKey: "customUserAttributes")
				i.setValue(123, forKey: "systemDataHash")
				i.setValue(CLLocation(latitude: 44.86803631018752, longitude: 13.84586334228516), forKey: "location")
				i.setValue(true, forKey: "regEnabled")
				i.setValue(true, forKey: "isPrimary")
				i.setValue(2, forKey: "logoutStatusValue")
				i.setValue(3, forKey: "logoutFailCounter")
				i.setValue(["t5", "t4"], forKey: "tags")
				i.setValue([instance], forKey: "instances")

			}
			coreDataProvider.context.MM_saveToPersistentStoreAndWait()

			XCTAssertEqual("extUserId", coreDataProvider.installationObject.value(forKey: "externalUserId") as! String)
			XCTAssertEqual("pushRegId", coreDataProvider.installationObject.value(forKey: "pushRegId") as! String)


            MobileMessaging.sharedInstance?.doStop()
			MobileMessaging.sharedInstance = nil
		}
		do {

			let storage = makeStorageForModel(at: "MMInternalStorageModel.momd/MMStorageModel_3")
			let mm = initMmWithStorage(storage)

			let installation = mm.resolveInstallation()
			let user = mm.resolveUser()
			let internalData = mm.internalData()

			XCTAssertEqual(user.firstName, "Darth")
			XCTAssertEqual(user.middleName, "_")
			XCTAssertEqual(user.lastName, "Vader")
			XCTAssertEqual(user.birthday, darthVaderDateOfBirth)
			XCTAssertEqual(user.gender, .Male)
			XCTAssertEqual(user.phones, ["79214444444"])
			XCTAssertEqual(user.emails, ["darth@vader.com"])
			XCTAssertEqual(user.externalUserId, "extUserId")
			XCTAssertEqual(user.customAttributes as! Dictionary, ["home": "tatooine"])
			XCTAssertEqual(user.tags, ["t5","t4"])
			XCTAssertEqual(user.installations, [instance])

			XCTAssertEqual(installation.pushRegistrationId, "pushRegId")
			XCTAssertEqual(installation.applicationUserId, "applicationUserId")

			XCTAssertEqual(installation.pushServiceToken, "device_token")
			XCTAssertEqual(installation.isPushRegistrationEnabled, true)
			XCTAssertEqual(installation.isPrimaryDevice, true)

			XCTAssertEqual(internalData.badgeNumber, 13)
			XCTAssertEqual(internalData.systemDataHash, 123)
			XCTAssertNotNil(internalData.location)
			XCTAssertEqual(internalData.currentDepersonalizationStatus, .success)
			XCTAssertEqual(internalData.depersonalizeFailCounter, 3)



            MobileMessaging.sharedInstance?.doStop()
			MobileMessaging.sharedInstance = nil
		}
	}

	private func makeStorageForModel(at modelPath: String) -> MMCoreDataStorage {
		return try! MMCoreDataStorage(settings:
			MMStorageSettings(modelName: modelPath, databaseFileName: "MobileMessaging.sqlite", storeOptions: MMStorageSettings.defaultStoreOptions))
	}

	private func initMmWithStorage(_ storage: MMCoreDataStorage) -> MobileMessaging {
		let mm = MobileMessaging(appCode: "appCode", notificationType: MMUserNotificationType.init(options: [.alert]), backendBaseURL: "http://url.com", internalStorage: storage)!
		mm.setupApiSessionManagerStubbed()
		MobileMessaging.application = ActiveApplicationStub()
		mm.apnsRegistrationManager = ApnsRegistrationManagerDisabledStub(mmContext: mm)

		return mm
	}
}
