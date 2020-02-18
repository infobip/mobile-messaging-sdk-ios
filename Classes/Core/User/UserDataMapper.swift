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
			Attributes.firstName.rawValue			: userAttributes.firstName as Any,
			Attributes.middleName.rawValue			: userAttributes.middleName as Any,
			Attributes.lastName.rawValue			: userAttributes.lastName as Any,
			Attributes.tags.rawValue				: userAttributes.tags?.asArray as Any,
			Attributes.gender.rawValue				: userAttributes.gender?.name as Any,
			Attributes.birthday.rawValue			: userAttributes.birthday != nil ? (DateStaticFormatters.ContactsServiceDateFormatter.string(from: userAttributes.birthday!) as Any) : (NSNull() as Any),
			Attributes.customAttributes.rawValue	: UserDataMapper.makeCustomAttributesPayload(userAttributes.customAttributes) as Any
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
		var ret: RequestBody = [ "userIdentity": personalizeRequestPayload(userIdentity: userIdentity) as Any ]
		if let userAttributes = userAttributes {
			ret = ret + [ "userAttributes": personalizeRequestPayload(userAttributes: userAttributes)  as Any ]
		}
		return ret
	}

	class func requestPayload(currentUser: User, dirtyUser: User) -> RequestBody {
		var ret = deltaDict(currentUser.dictionaryRepresentation, dirtyUser.dictionaryRepresentation)
		ret["installations"] = nil
		if let phones = (ret["phones"] as? [String]) {
			ret["phones"] = phones.reduce([[String: Any]](), { (result, phoneNumber) -> [[String: Any]] in
				let entry: [String: Any] = ["number": phoneNumber]
				return result + [entry]
			})
		}
		if let emails = (ret["emails"] as? [String]) {
			ret["emails"] = emails.reduce([[String: Any]](), { (result, address) -> [[String: Any]] in
				let entry: [String: Any] = ["address": address]
				return result + [entry]
			})
		}
		return ret
	}

	class func makeCustomAttributesPayload(_ userCustomAttributes: [String: AttributeType]?) -> [String: Any]? {
		guard let userCustomAttributes = userCustomAttributes else {
			return nil
		}
		let filteredCustomAttributes: [String: AttributeType] = userCustomAttributes

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

	class func apply(userSource: User, to userDestination: User) {
		userDestination.externalUserId = userSource.externalUserId
		userDestination.firstName = userSource.firstName
		userDestination.middleName = userSource.middleName
		userDestination.lastName = userSource.lastName
		userDestination.phones = userSource.phones
		userDestination.emails = userSource.emails
		userDestination.tags = userSource.tags
		userDestination.gender = userSource.gender
		userDestination.birthday = userSource.birthday
		userDestination.customAttributes = userSource.customAttributes
	}

	class func apply(userAttributes: UserAttributes, to user: User) {
		user.firstName = userAttributes.firstName
		user.middleName = userAttributes.middleName
		user.lastName = userAttributes.lastName
		user.tags = userAttributes.tags
		user.gender = userAttributes.gender
		user.birthday = userAttributes.birthday
		user.customAttributes = userAttributes.customAttributes
	}

	class func apply(userIdentity: UserIdentity, to user: User) {
		user.externalUserId = userIdentity.externalUserId
		user.phones = userIdentity.phones
		user.emails = userIdentity.emails
	}

}
