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

	class func personalizeRequestPayload(userAttributes: MMUserAttributes) -> RequestBody? {
		return userAttributes.dictionaryRepresentation.noNulls
	}

	class func personalizeRequestPayload(userIdentity: MMUserIdentity) -> RequestBody? {
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

	class func personalizeRequestPayload(userIdentity: MMUserIdentity, userAttributes: MMUserAttributes?) -> RequestBody? {
		var ret: RequestBody = [ "userIdentity": personalizeRequestPayload(userIdentity: userIdentity) as Any ]
		if let userAttributes = userAttributes {
			ret = ret + [ "userAttributes": personalizeRequestPayload(userAttributes: userAttributes)  as Any ]
		}
		return ret
	}

	class func requestPayload(currentUser: MMUser, dirtyUser: MMUser) -> RequestBody? {
		var ret = deltaDict(currentUser.dictionaryRepresentation, dirtyUser.dictionaryRepresentation)
		ret?["installations"] = nil
		if let phones = (ret?["phones"] as? [String]) {
			ret?["phones"] = phones.reduce([[String: Any]](), { (result, phoneNumber) -> [[String: Any]] in
				let entry: [String: Any] = ["number": phoneNumber]
				return result + [entry]
			})
		}
		if let emails = (ret?["emails"] as? [String]) {
			ret?["emails"] = emails.reduce([[String: Any]](), { (result, address) -> [[String: Any]] in
				let entry: [String: Any] = ["address": address]
				return result + [entry]
			})
		}
		return ret
	}

	class func makeCustomAttributesPayload(_ userCustomAttributes: [String: MMAttributeType]?) -> [String: Any]? {
		if let userCustomAttributes = userCustomAttributes, userCustomAttributes.isEmpty {
			return userCustomAttributes
		}
		return userCustomAttributes?
			.reduce([String: Any](), { result, pair -> [String: Any] in
				if let convertedValue = convertValue(input: pair.value) {
					return result + [pair.key: convertedValue]
				} else {
					return result
				}
			}).nilIfEmpty
	}

	class func convertValue(input: MMAttributeType) -> MMAttributeType? {
		switch input {
		case (is NSNumber):
			return input
		case (is NSString):
			return input
		case (is Date):
			return DateStaticFormatters.ContactsServiceDateFormatter.string(from: input as! Date) as NSString
		case (is MMDateTime):
			return DateStaticFormatters.ISO8601SecondsFormatter.string(from: (input as! MMDateTime).date as Date) as NSString
		case (is NSNull):
			return input
		case (is NSArray):
			return (input as! NSArray)
				.compactMap({ element -> [String: Any]? in
					if let element = element as? [String: MMAttributeType] {
						return makeCustomAttributesPayload(element)?.nilIfEmpty
					}
					return nil
				}).nilIfEmpty as MMAttributeType?
		default:
			return nil
		}
	}
	
	class func apply(userSource: MMUser, to userDestination: MMUser) {
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

	class func apply(userAttributes: MMUserAttributes, to user: MMUser) {
		user.firstName = userAttributes.firstName
		user.middleName = userAttributes.middleName
		user.lastName = userAttributes.lastName
		user.tags = userAttributes.tags
		user.gender = userAttributes.gender
		user.birthday = userAttributes.birthday
		user.customAttributes = userAttributes.customAttributes
	}

	class func apply(userIdentity: MMUserIdentity, to user: MMUser) {
		user.externalUserId = userIdentity.externalUserId
		user.phones = userIdentity.phones
		user.emails = userIdentity.emails
	}

}
