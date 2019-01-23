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

	func testDataModelMigration() {
		MobileMessaging.stop(true) //removes any existing storage

		do {
			let storage = makeStorageForModel(at: "MMInternalStorageModel.momd/MMStorageModel")
			let mm = startMmWithStorage(storage)

			mm.coreDataProvider.context.performAndWait {
				mm.coreDataProvider.installationObject.setValue(["firstName": "Darth",
																 "middleName": "_",
																 "lastName": "Vader",
																 "birthdate": "1980-12-12",
																 "gender": "M",
																 "msisdn": "79214444444",
																 "email": "darth@vader.com"], forKey: "predefinedUserData")
				mm.coreDataProvider.installationObject.setValue("pushRegId", forKey: "internalUserId")
				mm.coreDataProvider.installationObject.setValue("extUserId", forKey: "externalUserId")
				mm.coreDataProvider.installationObject.setValue(13, forKey: "badgeNumber")
				mm.coreDataProvider.installationObject.setValue("device_token", forKey: "deviceToken")
				mm.coreDataProvider.installationObject.setValue(["home": "tatooine"], forKey: "customUserData")
				mm.coreDataProvider.installationObject.setValue(123, forKey: "systemDataHash")
				mm.coreDataProvider.installationObject.setValue(CLLocation(latitude: 44.86803631018752, longitude: 13.84586334228516), forKey: "location")
				mm.coreDataProvider.installationObject.setValue(true, forKey: "isRegistrationEnabled")
				mm.coreDataProvider.installationObject.setValue(true, forKey: "isPrimaryDevice")
				mm.coreDataProvider.installationObject.setValue(2, forKey: "logoutStatusValue")
				mm.coreDataProvider.installationObject.setValue(3, forKey: "logoutFailCounter")
			}

			mm.coreDataProvider.context.MM_saveToPersistentStoreAndWait()


			XCTAssertEqual("extUserId", mm.coreDataProvider.installationObject.value(forKey: "externalUserId") as! String)
			// ...
			XCTAssertEqual("pushRegId", mm.coreDataProvider.installationObject.value(forKey: "internalUserId") as! String)
			XCTAssertEqual(["firstName": "Darth",
							"middleName": "_",
							"lastName": "Vader",
							"birthdate": "1980-12-12",
							"gender": "M",
							"msisdn": "79214444444",
							"email": "darth@vader.com"], mm.coreDataProvider.installationObject.value(forKey: "predefinedUserData") as! Dictionary)

			MobileMessaging.stop(false)
			MobileMessaging.sharedInstance = nil
		}
		do {
			let storage = makeStorageForModel(at: "MMInternalStorageModel.momd/MMStorageModel_2")
			let mm = startMmWithStorage(storage)

			let installationObj_v2 = mm.coreDataProvider.installationObject

			XCTAssertEqual(installationObj_v2.value(forKey: "firstName") as! String, "Darth")
			XCTAssertEqual(installationObj_v2.value(forKey: "middleName") as! String, "_")
			XCTAssertEqual(installationObj_v2.value(forKey: "lastName") as! String, "Vader")
			XCTAssertEqual(installationObj_v2.value(forKey: "birthday") as! String, "1980-12-12")
			XCTAssertEqual(installationObj_v2.value(forKey: "gender") as! String, "Male")
			XCTAssertEqual(installationObj_v2.value(forKey: "phones") as! [Phone], [Phone(number: "79214444444", preferred: false)])
			XCTAssertEqual((installationObj_v2.value(forKey: "emails") as! [Email]).first?.address, "darth@vader.com")
			XCTAssertEqual((installationObj_v2.value(forKey: "emails") as! [Email]).first?.preferred, false)
			XCTAssertEqual(installationObj_v2.value(forKey: "pushRegId") as! String, "pushRegId")
			XCTAssertEqual(installationObj_v2.value(forKey: "externalUserId") as! String, "extUserId")
			XCTAssertEqual(installationObj_v2.value(forKey: "applicationUserId") as? String, nil)
			XCTAssertEqual(installationObj_v2.value(forKey: "badgeNumber") as! Int, 13)
			XCTAssertEqual(installationObj_v2.value(forKey: "pushServiceToken") as! String, "device_token")
			XCTAssertEqual(installationObj_v2.value(forKey: "customUserAttributes") as! Dictionary, ["home": "tatooine"])
			XCTAssertEqual(installationObj_v2.value(forKey: "systemDataHash") as! Int, 123)
			XCTAssertNotNil(installationObj_v2.value(forKey: "location"))
			XCTAssertEqual(installationObj_v2.value(forKey: "regEnabled") as! Bool, true)
			XCTAssertEqual(installationObj_v2.value(forKey: "isPrimary") as! Bool, true)
			XCTAssertEqual(installationObj_v2.value(forKey: "logoutStatusValue") as! Int, 2)
			XCTAssertEqual(installationObj_v2.value(forKey: "logoutFailCounter") as! Int, 3)
			XCTAssertEqual(installationObj_v2.value(forKey: "tags") as? [String], nil)
			XCTAssertEqual(installationObj_v2.value(forKey: "instances") as? [Installation], nil)

			MobileMessaging.stop(false)
			MobileMessaging.sharedInstance = nil
		}
	}

	private func makeStorageForModel(at modelPath: String) -> MMCoreDataStorage {
		return try! MMCoreDataStorage(settings:
			MMStorageSettings(modelName: modelPath, databaseFileName: "MobileMessaging.sqlite", storeOptions: MMStorageSettings.defaultStoreOptions))
	}

	private func startMmWithStorage(_ storage: MMCoreDataStorage) -> MobileMessaging {
		let mm = MobileMessaging(appCode: "appCode", notificationType: UserNotificationType.init(options: [.alert]), backendBaseURL: "", forceCleanup: false, internalStorage: storage)!
		mm.setupMockedQueues()
		MobileMessaging.application = ActiveApplicationStub()
		mm.apnsRegistrationManager = ApnsRegistrationManagerDisabledStub(mmContext: mm)
//		mm.start()
		return mm
	}
}
