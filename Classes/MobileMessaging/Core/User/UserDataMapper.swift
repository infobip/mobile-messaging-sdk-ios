// 
//  UserDataMapper.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
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

	/// The fields a write of `user` changes: what differs from the server-confirmed user, plus what differs from
	/// the previous local user (a revert of a pending change equals the server-confirmed user, but must still be
	/// sent). Shaped like a request body; nested dictionaries (custom attributes) list their changed sub-keys.
	class func changedFields(of user: MMUser, currentUser: MMUser, previousUser: MMUser) -> RequestBody {
		return mergeFields(requestPayload(currentUser: currentUser, dirtyUser: user) ?? [:],
						   requestPayload(currentUser: previousUser, dirtyUser: user) ?? [:])
	}

	/// `payload` limited to `fields`. In `fields` a non-empty nested dictionary selects only those sub-keys
	/// (custom attributes); any other value selects the whole field.
	class func restrict(_ payload: RequestBody, to fields: RequestBody) -> RequestBody {
		var ret = RequestBody()
		for (key, value) in payload {
			guard let mask = fields[key] else { continue }
			guard let subKeys = subMask(mask) else {
				ret[key] = value
				continue
			}
			if let nested = value as? RequestBody {
				let restricted = restrict(nested, to: subKeys)
				if !restricted.isEmpty { ret[key] = restricted }
			} else {
				// the whole field is cleared: clear only the selected sub-keys
				ret[key] = subKeys.mapValues { _ in NSNull() }
			}
		}
		return ret
	}

	private class func mergeFields(_ a: RequestBody, _ b: RequestBody) -> RequestBody {
		var ret = a
		for (key, value) in b {
			guard let existing = ret[key] else {
				ret[key] = value
				continue
			}
			if let left = subMask(existing), let right = subMask(value) {
				ret[key] = mergeFields(left, right)
			} else if subMask(existing) != nil {
				ret[key] = value // the whole field selects more than some sub-keys
			}
		}
		return ret
	}

	private class func subMask(_ value: Any) -> RequestBody? {
		guard let dict = value as? RequestBody, !dict.isEmpty else { return nil }
		return dict
	}

	class func requestPayload(currentUser: MMUser, dirtyUser: MMUser) -> RequestBody? {
		var ret = deltaDict(currentUser.dictionaryRepresentation, dirtyUser.dictionaryRepresentation)
		ret?["installations"] = nil
        ret?["type"] = nil
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
		// Only update fields that are explicitly provided (non-nil) to prevent clearing existing data in partial updates
		if let externalUserId = userIdentity.externalUserId {
			user.externalUserId = externalUserId
		}
		if let phones = userIdentity.phones {
			user.phones = phones
		}
		if let emails = userIdentity.emails {
			user.emails = emails
		}
	}

}
