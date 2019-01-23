//
//  MigrationPolicy.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 06/11/2018.
//

import Foundation
import CoreData

class InstallationMigrationPolicy : NSEntityMigrationPolicy {
	override func createDestinationInstances(forSource sInstance: NSManagedObject, in mapping: NSEntityMapping, manager: NSMigrationManager) throws {
		guard
			(mapping.userInfo?["version"] as? String) == "2",
			let destinationEntityName = mapping.destinationEntityName
			else
		{
			try super.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)
			return
		}

		let destinationInstallation = NSEntityDescription.insertNewObject(forEntityName: destinationEntityName, into: manager.destinationContext)
		let predefinedUserData = sInstance.value(forKey: "predefinedUserData") as? [String: Any]


		destinationInstallation.setValue(sInstance.value(forKey: "applicationCode"), 	forKey: "applicationCode")
		destinationInstallation.setValue(nil,											forKey: "applicationUserId")
		destinationInstallation.setValue(nil,											forKey: "customInstanceAttributes")
		destinationInstallation.setValue(sInstance.value(forKey: "badgeNumber"), 		forKey: "badgeNumber")
		destinationInstallation.setValue(predefinedUserData?["birthdate"] as? String, 	forKey: "birthday")
		destinationInstallation.setValue(sInstance.value(forKey: "customUserData"), 	forKey: "customUserAttributes")
		destinationInstallation.setValue(nil, 											forKey: "dirtyAttributesString")
		destinationInstallation.setValue(migrateEmail(from: predefinedUserData), 		forKey: "emails")
		destinationInstallation.setValue(sInstance.value(forKey: "externalUserId"), 	forKey: "externalUserId")
		destinationInstallation.setValue(predefinedUserData?["firstName"] as? String, 	forKey: "firstName")
		destinationInstallation.setValue(migrateGender(from: predefinedUserData), 		forKey: "gender")
		destinationInstallation.setValue(migrateMsisdn(from: predefinedUserData),		forKey: "phones")
		destinationInstallation.setValue(nil, 											forKey: "instances")
		destinationInstallation.setValue(sInstance.value(forKey: "isPrimaryDevice"), 	forKey: "isPrimary")
		destinationInstallation.setValue(predefinedUserData?["lastName"] as? String, 	forKey: "lastName")
		destinationInstallation.setValue(sInstance.value(forKey: "location"), 			forKey: "location")
		destinationInstallation.setValue(sInstance.value(forKey: "logoutFailCounter"), 	forKey: "logoutFailCounter")
		destinationInstallation.setValue(sInstance.value(forKey: "logoutStatusValue"), 	forKey: "logoutStatusValue")
		destinationInstallation.setValue(predefinedUserData?["middleName"] as? String, 	forKey: "middleName")
		destinationInstallation.setValue(sInstance.value(forKey: "internalUserId"), 	forKey: "pushRegId")
		destinationInstallation.setValue(sInstance.value(forKey: "deviceToken"), 		forKey: "pushServiceToken")
		destinationInstallation.setValue(sInstance.value(forKey: "isRegistrationEnabled"), forKey: "regEnabled")
		destinationInstallation.setValue(sInstance.value(forKey: "systemDataHash"), 	forKey: "systemDataHash")
		destinationInstallation.setValue(nil, 											forKey: "tags")


		manager.associate(sourceInstance: sInstance, withDestinationInstance: destinationInstallation, for: mapping)
	}

	private func migrateEmail(from predefinedUserData: [String: Any]?) -> Any? {
		if let address = predefinedUserData?["email"] as? String {
			return [Email(address: address, preferred: false)]
		} else {
			return nil
		}
	}

	private func migrateGender(from predefinedUserData: [String: Any]?) -> Any? {
		if let gender = predefinedUserData?["gender"] as? String {
			let migratedGender: String?
			switch gender {
			case "M":
				migratedGender = "Male"
			case "F":
				migratedGender = "Female"
			default:
				migratedGender = nil
			}
			return migratedGender
		} else {
			return nil
		}
	}

	private func migrateMsisdn(from predefinedUserData: [String: Any]?) -> Any? {
		if let number = predefinedUserData?["msisdn"] as? String {
			return [Phone(number: number, preferred: false)]
		} else {
			return nil
		}
	}
}
