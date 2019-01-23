//
//  InstallationStorageAttributes.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 29/11/2018.
//

import Foundation

enum TopAttributeKeyStrings : String {
	case pushServiceToken = "pushServiceToken"
	case customUserAttributes = "customUserAttributes"
	case customInstanceAttributes = "customInstanceAttributes"
	case externalUserId = "externalUserId"
	case registrationEnabled = "regEnabled"
	case applicationCode = "applicationCode"
	case badgeNumber = "badgeNumber"
	case systemDataHash = "systemDataHash"
	case location = "location"
	case pushRegistrationId = "pushRegId"
	case isPrimaryDevice = "isPrimary"
	case logoutStatusValue = "logoutStatusValue"
	case logoutFailCounter = "logoutFailCounter"
	case phones = "phones"
	case firstName = "firstName"
	case lastName = "lastName"
	case middleName = "middleName"
	case gender = "gender"
	case birthday = "birthday"
	case emails = "emails"
	case tags = "tags"
	case instances = "instances"
	case applicationUserId = "applicationUserId"

	static func fromAttributes(_ atts: Attributes) -> TopAttributeKeyStrings {
		switch atts {
		case .pushServiceToken: return .pushServiceToken
		case .customUserAttributes: return .customUserAttributes
		case .customUserAttribute: return .customUserAttributes
		case .customInstanceAttributes: return .customInstanceAttributes
		case .customInstanceAttribute: return .customInstanceAttributes
		case .externalUserId: return .externalUserId
		case .registrationEnabled: return .registrationEnabled
		case .applicationCode: return .applicationCode
		case .badgeNumber: return .badgeNumber
		case .systemDataHash: return .systemDataHash
		case .location: return .location
		case .pushRegistrationId: return .pushRegistrationId
		case .isPrimaryDevice: return .isPrimaryDevice
		case .depersonalizeStatusValue: return .logoutStatusValue
		case .depersonalizeFailCounter: return .logoutFailCounter
		case .phones: return .phones
		case .firstName: return .firstName
		case .lastName: return .lastName
		case .middleName: return .middleName
		case .gender: return .gender
		case .birthday: return .birthday
		case .emails: return .emails
		case .tags: return .tags
		case .instances: return .instances
		case .applicationUserId: return .applicationUserId
		}
	}

	var toAttributes: Attributes? {
		switch self {
		case .pushServiceToken: return .pushServiceToken
		case .customUserAttributes: return .customUserAttributes
		case .customInstanceAttributes: return .customInstanceAttributes
		case .externalUserId: return .externalUserId
		case .registrationEnabled: return .registrationEnabled
		case .applicationCode: return .applicationCode
		case .badgeNumber: return .badgeNumber
		case .systemDataHash: return .systemDataHash
		case .location: return .location
		case .pushRegistrationId: return .pushRegistrationId
		case .isPrimaryDevice: return .isPrimaryDevice
		case .logoutStatusValue: return .depersonalizeStatusValue
		case .logoutFailCounter: return .depersonalizeFailCounter
		case .phones: return .phones
		case .firstName: return .firstName
		case .lastName: return .lastName
		case .middleName: return .middleName
		case .gender: return .gender
		case .birthday: return .birthday
		case .emails: return .emails
		case .tags: return .tags
		case .instances: return .instances
		case .applicationUserId: return .applicationUserId
		}
	}
}

enum Attributes: Hashable {
	// case -> model name
	case phones
	case firstName
	case lastName
	case middleName
	case gender
	case birthday
	case emails
	case tags
	case pushServiceToken
	case customUserAttributes
	case customUserAttribute(key: String)
	case externalUserId
	case registrationEnabled
	case applicationCode
	case badgeNumber
	case systemDataHash
	case location
	case pushRegistrationId
	case isPrimaryDevice
	case depersonalizeStatusValue
	case depersonalizeFailCounter
	case instances
	case applicationUserId
	case customInstanceAttributes
	case customInstanceAttribute(key: String)

	var key: String? {
		switch self {
		case .customUserAttribute(let key): return key
		case .customInstanceAttribute(let key): return key
		default: return nil
		}
	}

	var isCustomUserAttribute: Bool {
		switch self {
		case .customUserAttribute, .customUserAttributes:
			return true
		default:
			return false
		}
	}

	var isCustomInstanceAttribute: Bool {
		switch self {
		case .customInstanceAttribute, .customInstanceAttributes:
			return true
		default:
			return false
		}
	}

	var requestPayloadKey: String {
		switch self {
		case .customInstanceAttributes, .customUserAttributes, .customInstanceAttribute, .customUserAttribute:
			return "customAttributes"
		default:
			return databaseKey
		}
	}

	var databaseKey: String {
		return TopAttributeKeyStrings.fromAttributes(self).rawValue
	}

	static func fromString(_ s: String) -> Attributes? {
		switch (s) {
		case let str where str.contains(TopAttributeKeyStrings.customUserAttributes.rawValue+"."):
			if let key = str.components(separatedBy: ".").last {
				return Attributes.customUserAttribute(key: key)
			}else{
				return nil
			}
		case let str where str.contains(TopAttributeKeyStrings.customInstanceAttributes.rawValue+"."):
			if let key = str.components(separatedBy: ".").last {
				return Attributes.customInstanceAttribute(key: key)
			}else{
				return nil
			}
		default: return TopAttributeKeyStrings(rawValue: s)?.toAttributes
		}

	}

	var rawValue: String {
		switch self {
		case .customUserAttribute(let key): return TopAttributeKeyStrings.customUserAttributes.rawValue + "." + key
		case .customInstanceAttribute(let key): return TopAttributeKeyStrings.customInstanceAttributes.rawValue + "." + key
		default: return databaseKey
		}
	}

	static var standardAttributesSet: AttributesSet { return	[
		.instances,
		.phones,
		.emails,
		.tags,
		.firstName,
		.lastName,
		.middleName,
		.birthday,
		.gender,
		.externalUserId]}

	static var userDataAttributesSet: AttributesSet {
		return standardAttributesSet.union([Attributes.customUserAttributes])
	}

	static var standardInstanceAttributesSet: AttributesSet { return[
		.applicationUserId,
		.isPrimaryDevice,
		.pushRegistrationId,
		.systemDataHash]}

	static var registrationAttributesSet: AttributesSet { return[
		.pushServiceToken,
		.registrationEnabled]}

	static var instanceAttributesSet: AttributesSet { return Set([
		.customInstanceAttributes]).union(
		registrationAttributesSet).union(
		standardInstanceAttributesSet)}

	static var registrationAttributesString: String {
		return registrationAttributesSet.map({$0.rawValue}).joined(separator: ",")
	}

	public var hashValue: Int { return rawValue.stableHash }
}

typealias AttributesSet = Set<Attributes>
extension Set where Element == Attributes {
	mutating func removeAttributes(_ members: AttributesSet) {
		var ar: Array<Attributes> = Array(self)
		if members.contains(.customUserAttributes) {
			ar.removeAll {$0.isCustomUserAttribute}
		}
		if members.contains(.customInstanceAttributes) {
			ar.removeAll {$0.isCustomInstanceAttribute}
		}
		self = Set(ar)
		self.subtract(members)
	}

	func intersectsWith(_ attributeSet: AttributesSet) -> Bool {
		for otherAtt in attributeSet {
			if self.contains(otherAtt) {
				return true
			}
			switch otherAtt {
			case .customUserAttribute:
				if self.contains(.customUserAttributes) {
					return true
				} else {
					fallthrough
				}
			case .customUserAttributes:
				if self.contains(where: {
					switch $0 {
					case .customUserAttribute: return true
					default: return false
					}
				}) {
					return true
				} else {
					fallthrough
				}
			default: break
			}
		}
		return false
	}
}
