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
		guard mapping.destinationEntityName != nil
			else
		{
			try super.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)
			return
		}

		MMLogDebug("[MobileMessaging] starting \(String(describing: mapping.userInfo?["version"] as? String)) migration")
		switch (mapping.userInfo?["version"] as? String) {
		case "0_3", "1_3":
			let predefinedUserData = sInstance.value(forKey: "predefinedUserData") as? [String: Any]
			let installation = Installation.unarchiveCurrent()
			installation.applicationUserId = nil
			installation.customAttributes = [:]
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


			user.archiveAll()
			installation.archiveAll()
			internalData.archiveCurrent()
			break
		case "2_3":
			let installation = Installation.unarchiveCurrent()
			installation.applicationUserId = sInstance.value(forKey: "applicationUserId") as? String
			installation.customAttributes = (sInstance.value(forKey: "customInstanceAttributes") as? [String: AttributeType]) ?? [:]
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
			user.tags = Set(sInstance.value(forKey: "tags") as? [String] ?? [])


			let internalData = InternalData.unarchiveCurrent()
			internalData.applicationCode = sInstance.value(forKey: "applicationCode") as? String
			internalData.badgeNumber = (sInstance.value(forKey: "badgeNumber") as? Int) ?? 0
			internalData.location = sInstance.value(forKey: "location") as? CLLocation
			internalData.depersonalizeFailCounter = (sInstance.value(forKey: "logoutFailCounter") as? Int) ?? 0
			internalData.currentDepersonalizationStatus = (sInstance.value(forKey: "logoutStatusValue") as? Int).ifSome({SuccessPending(rawValue: $0)}) ?? .undefined
			internalData.systemDataHash = (sInstance.value(forKey: "systemDataHash") as? Int64) ?? 0
			internalData.registrationDate = Date()

			user.archiveAll()
			installation.archiveAll()
			internalData.archiveCurrent()
			break
		default:
			break
		}
		MMLogDebug("[MobileMessaging] migration \(String(describing: mapping.userInfo?["version"] as? String)) finished")
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
