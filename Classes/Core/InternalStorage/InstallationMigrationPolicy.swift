//
//  MigrationPolicy.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 06/11/2018.
//

import Foundation
import CoreData
import CoreLocation

class InstallationMigrationPolicy : NSEntityMigrationPolicy {
	override func createDestinationInstances(forSource sInstance: NSManagedObject, in mapping: NSEntityMapping, manager: NSMigrationManager) throws {
		guard let destinationEntityName = mapping.destinationEntityName
			else
		{
			try super.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)
			return
		}

		switch (mapping.userInfo?["version"] as? String) {
		case "1_2":
			let destinationInstallation = NSEntityDescription.insertNewObject(forEntityName: destinationEntityName, into: manager.destinationContext)
			let predefinedUserData = sInstance.value(forKey: "predefinedUserData") as? [String: Any]


			destinationInstallation.setValue(sInstance.value(forKey: "applicationCode"), 	forKey: "applicationCode")
			destinationInstallation.setValue(nil,											forKey: "applicationUserId")
			destinationInstallation.setValue(nil,											forKey: "customInstanceAttributes")
			destinationInstallation.setValue(sInstance.value(forKey: "badgeNumber"), 		forKey: "badgeNumber")
			destinationInstallation.setValue(predefinedUserData?["birthdate"] as? String, 	forKey: "birthday")
			destinationInstallation.setValue(sInstance.value(forKey: "customUserData"), 	forKey: "customUserAttributes")
			destinationInstallation.setValue(sInstance.value(forKey: "dirtyAttributesString"),forKey: "dirtyAttributesString")
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
		case "1_3":
			let predefinedUserData = sInstance.value(forKey: "predefinedUserData") as? [String: Any]
			let installation = Installation.unarchiveCurrent()
			installation.applicationUserId = nil
			installation.customAttributes = nil
			installation.isPrimaryDevice = (sInstance.value(forKey: "isPrimaryDevice") as? Bool) ?? false
			installation.pushRegistrationId = sInstance.value(forKey: "internalUserId") as? String
			installation.pushServiceToken = sInstance.value(forKey: "deviceToken") as? String
			installation.isPushRegistrationEnabled = (sInstance.value(forKey: "isRegistrationEnabled") as? Bool) ?? true

			let user = User.unarchiveCurrent()
			user.birthday = (predefinedUserData?["birthdate"] as? String).ifSome({ return DateStaticFormatters.ContactsServiceDateFormatter.date(from: $0)})
			user.customAttributes = sInstance.value(forKey: "customUserData") as? [String: AttributeType]
			user.emails = migrateEmailStrings(from: predefinedUserData)
			user.externalUserId = sInstance.value(forKey: "externalUserId") as? String
			user.firstName = predefinedUserData?["firstName"] as? String
			user.gender = migrateGenderToEnum(from: predefinedUserData)
			user.phones = migratePhonesStrings(from: predefinedUserData)
			user.installations = nil
			user.lastName = predefinedUserData?["lastName"] as? String
			user.middleName = predefinedUserData?["middleName"] as? String
			user.tags = nil


			let internalData = InternalData.unarchiveCurrent()
			internalData.applicationCode = sInstance.value(forKey: "applicationCode") as? String
			internalData.badgeNumber = (sInstance.value(forKey: "badgeNumber") as? Int) ?? 0
			internalData.location = sInstance.value(forKey: "location") as? CLLocation
			internalData.depersonalizeFailCounter = (sInstance.value(forKey: "logoutFailCounter") as? Int) ?? 0
	 		internalData.currentDepersonalizationStatus = (sInstance.value(forKey: "logoutStatusValue") as? Int).ifSome({SuccessPending(rawValue: $0)}) ?? .undefined
			internalData.systemDataHash = (sInstance.value(forKey: "systemDataHash") as? Int64) ?? 0
			internalData.registrationDate = Date()

			User.empty.archiveCurrent()
			user.archiveDirty()
			Installation.empty.archiveCurrent()
			installation.archiveDirty()
			internalData.archiveCurrent()

			break
		case "2_3":
			let installation = Installation.unarchiveCurrent()
			installation.applicationUserId = sInstance.value(forKey: "applicationUserId") as? String
			installation.customAttributes = sInstance.value(forKey: "customInstanceAttributes") as? [String: AttributeType]
			installation.isPrimaryDevice = (sInstance.value(forKey: "isPrimary") as? Bool) ?? false
			installation.pushRegistrationId = sInstance.value(forKey: "pushRegId") as? String
			installation.pushServiceToken = sInstance.value(forKey: "pushServiceToken") as? String
			installation.isPushRegistrationEnabled = (sInstance.value(forKey: "regEnabled") as? Bool) ?? true

			let user = User.unarchiveCurrent()
			user.birthday = (sInstance.value(forKey: "birthday") as? String).ifSome({ return DateStaticFormatters.ContactsServiceDateFormatter.date(from: $0)})
			user.customAttributes = sInstance.value(forKey: "customUserAttributes") as? [String: AttributeType]
			user.emailsObjects = sInstance.value(forKey: "emails") as? [Email]
			user.externalUserId = sInstance.value(forKey: "externalUserId") as? String
			user.firstName = sInstance.value(forKey: "firstName") as? String
			user.gender = (sInstance.value(forKey: "gender") as? String).ifSome({ return Gender.make(with: $0) })
			user.phonesObjects = sInstance.value(forKey: "phones") as? [Phone]
			user.installations = sInstance.value(forKey: "instances") as? [Installation]
			user.lastName = sInstance.value(forKey: "lastName") as? String
			user.middleName = sInstance.value(forKey: "middleName") as? String
			user.tags = sInstance.value(forKey: "tags") as? [String]


			let internalData = InternalData.unarchiveCurrent()
			internalData.applicationCode = sInstance.value(forKey: "applicationCode") as? String
			internalData.badgeNumber = (sInstance.value(forKey: "badgeNumber") as? Int) ?? 0
			internalData.location = sInstance.value(forKey: "location") as? CLLocation
			internalData.depersonalizeFailCounter = (sInstance.value(forKey: "logoutFailCounter") as? Int) ?? 0
			internalData.currentDepersonalizationStatus = (sInstance.value(forKey: "logoutStatusValue") as? Int).ifSome({SuccessPending(rawValue: $0)}) ?? .undefined
			internalData.systemDataHash = (sInstance.value(forKey: "systemDataHash") as? Int64) ?? 0
			internalData.registrationDate = Date()

			User.empty.archiveCurrent()
			user.archiveDirty()
			Installation.empty.archiveCurrent()
			installation.archiveDirty()
			internalData.archiveCurrent()

			break
		default:
			break
		}
	}

	private func migrateEmail(from predefinedUserData: [String: Any]?) -> Any? {
		if let address = predefinedUserData?["email"] as? String {
			return [Email(address: address, preferred: false)]
		} else {
			return nil
		}
	}

	private func migrateEmailStrings(from predefinedUserData: [String: Any]?) -> [String]? {
		if let address = predefinedUserData?["email"] as? String {
			return [address]
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

	private func migrateGenderToEnum(from predefinedUserData: [String: Any]?) -> Gender? {
		if let genderString = migrateGender(from: predefinedUserData) as? String {
			return Gender.make(with: genderString)
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

	private func migratePhonesStrings(from predefinedUserData: [String: Any]?) -> [String]? {
		if let number = predefinedUserData?["msisdn"] as? String {
			return [number]
		} else {
			return nil
		}
	}
}
