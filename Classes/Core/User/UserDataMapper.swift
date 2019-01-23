//
//  UserDataMapper.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 14/01/2019.
//

import Foundation

protocol OptionalProtocol {}
extension Optional : OptionalProtocol {}

class UserDataMapper {

	class func personalizeRequestPayload(userAttributes: UserAttributes) -> RequestBody? {
		return [
			Attributes.firstName.requestPayloadKey			: userAttributes.firstName as Any,
			Attributes.middleName.requestPayloadKey			: userAttributes.middleName as Any,
			Attributes.lastName.requestPayloadKey			: userAttributes.lastName as Any,
			Attributes.tags.requestPayloadKey				: userAttributes.tags as Any,
			Attributes.gender.requestPayloadKey				: userAttributes.gender?.name as Any,
			Attributes.birthday.requestPayloadKey			: userAttributes.birthday != nil ? (DateStaticFormatters.ContactsServiceDateFormatter.string(from: userAttributes.birthday!) as Any) : (NSNull() as Any),
			Attributes.customUserAttributes.requestPayloadKey	: UserDataMapper.makeCustomAttributesPayload(userAttributes.customAttributes, attributesSet: nil) as Any
		].noNulls
	}

	class func personalizeRequestPayload(userIdentity: UserIdentity) -> RequestBody? {
		var ret = RequestBody()
		if let phones = userIdentity.phones, !phones.isEmpty {
			ret = ret + ["phones": phones.reduce([[String: Any]](), { (ret, phone) -> [[String: Any]] in
				let entry = ["number": phone] as [String: Any]
				return ret + [entry]
			})]
		}
		if let emails = userIdentity.emails, !emails.isEmpty {
			ret = ret + ["emails": emails.reduce([[String: Any]](), { (ret, email) -> [[String: Any]] in
				let entry = ["address": email] as [String: Any]
				return ret + [entry]
			})]
		}
		if let externalUserId = userIdentity.externalUserId {
			ret = ret + ["externalUserId": externalUserId]
		}

		return ret
	}

	class func personalizeRequestPayload(userIdentity: UserIdentity, userAttributes: UserAttributes?) -> RequestBody? {
		var ret: RequestBody = [ "userIdentity": personalizeRequestPayload(userIdentity: userIdentity) ]
		if let userAttributes = userAttributes {
			ret = ret + [ "userAttributes": personalizeRequestPayload(userAttributes: userAttributes) ]
		}
		return ret
	}

	class func requestPayload(with user: UserDataService, forAttributesSet attributesSet: Set<Attributes>) -> RequestBody? {
		MMLogVerbose("Making request payload for attributes: \(attributesSet)")
		let standardAttributes: [String: Any] = attributesSet
			.intersection(Attributes.standardAttributesSet)
			.subtracting([.instances])
			.reduce([String: Any](), { (dict, att) -> [String: Any] in
				var dict = dict
				let val = user.getValueForKey(att) ?? NSNull()
				switch att {
				case .phones:
					dict[att.requestPayloadKey] = (val as? Array<Phone>)?.map({ return $0.dictionaryRepresentation })
				case .emails:
					dict[att.requestPayloadKey] = (val as? Array<Email>)?.map({ return $0.dictionaryRepresentation })
				default:
					dict[att.requestPayloadKey] = val
				}
				return dict
			})

		let customAttributes = UserDataMapper.makeCustomAttributesPayload(user.customAttributes, attributesSet: attributesSet)

		var ret: [String: Any] = standardAttributes
		if let customAttributes = customAttributes, !customAttributes.isEmpty {
			ret[Attributes.customUserAttributes.requestPayloadKey] = customAttributes
		}

		return ret
	}

	class func makeCustomAttributesPayload(_ userCustomAttributes: [String: AttributeType]?, attributesSet: AttributesSet?) -> [String: Any]? {
		guard let userCustomAttributes = userCustomAttributes else {
			return nil
		}
		let filteredCustomAttributes: [String: AttributeType]
		if let attributesSet = attributesSet {
			filteredCustomAttributes = userCustomAttributes
				.filter({ pair -> Bool in
					attributesSet.contains(where: { (attribute) -> Bool in
						switch (attribute) {
						case .customUserAttribute(let key): return key == pair.key
						case .customUserAttributes: return true
						default: return false
						}
					})
				})
		} else {
			filteredCustomAttributes = userCustomAttributes
		}

		return filteredCustomAttributes
			.reduce([String: Any](), { result, pair -> [String: Any] in
				var value: AttributeType = pair.value
				switch value {
				case (is NSNumber):
					break;
				case (is NSString):
					break;
				case (is Date):
					value = DateStaticFormatters.ContactsServiceDateFormatter.string(from: value as! Date) as NSString
				case (is NSNull):
					break;
				default:
					break;
				}
				return result + [pair.key: value]
			})
	}

	class func apply(userData: User, to currentUser: UserDataService) {
		currentUser.externalUserId = userData.externalUserId
		currentUser.firstName = userData.firstName
		currentUser.middleName = userData.middleName
		currentUser.lastName = userData.lastName
		currentUser.phones = userData.phones
		currentUser.emails = userData.emails
		currentUser.tags = userData.tags
		currentUser.gender = userData.gender
		currentUser.birthday = userData.birthday
		currentUser.customAttributes = userData.customAttributes
	}
}
