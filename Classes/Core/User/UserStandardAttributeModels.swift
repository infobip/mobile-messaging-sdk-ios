//
//  UserStandardAttributeModels.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 29/11/2018.
//

import Foundation

@objc public enum Gender: Int {
	case Female
	case Male

	public var name: String {
		switch self {
		case .Female : return "Female"
		case .Male : return "Male"
		}
	}

	static func make(with name: String) -> Gender? {
		switch name {
		case "Female":
			return Gender.Female
		case "Male":
			return Gender.Male
		default:
			return nil
		}
	}
}

public protocol PreferredSupported : Hashable {
	var preferred: Bool {set get}
}

final class Phone: NSObject, NSCoding, JSONDecodable, DictionaryRepresentable, PreferredSupported {
	public let number: String
	public var preferred: Bool
	// more properties needed? ok but look at the code below first.

	required init?(dictRepresentation dict: DictionaryRepresentation) {
		fatalError("init(dictRepresentation:) has not been implemented")
	}

	var dictionaryRepresentation: DictionaryRepresentation {
		return ["number": number]
	}

	public override var hash: Int {
		return number.hashValue// ^ preferred.hashValue // use hasher combine
	}

	public override func isEqual(_ object: Any?) -> Bool {
		guard let object = object as? Phone else {
			return false
		}
		return self.number == object.number
	}

	convenience init?(json: JSON) {
		let preferred = false
		guard let number = json["number"].string else { // preferred is not supported yet on mobile api
			return nil
		}
		self.init(number: number, preferred: preferred)
	}

	public init(number: String, preferred: Bool) {
		self.number = number
		self.preferred = preferred
	}

	required public init?(coder aDecoder: NSCoder) {
		number = aDecoder.decodeObject(forKey: "number") as! String
		preferred = aDecoder.decodeBool(forKey: "preferred")
	}

	public func encode(with aCoder: NSCoder) {
		aCoder.encode(number, forKey: "number")
		aCoder.encode(preferred, forKey: "preferred")
	}
}

final class Email: NSObject, NSCoding, JSONDecodable, DictionaryRepresentable, PreferredSupported {
	public let address: String
	public var preferred: Bool
	// more properties needed? ok but look at the code below first.

	required init?(dictRepresentation dict: DictionaryRepresentation) {
		fatalError("init(dictRepresentation:) has not been implemented")
	}

	var dictionaryRepresentation: DictionaryRepresentation {
		return ["address": address]
	}

	public override var hash: Int {
		return address.hashValue// ^ preferred.hashValue // use hasher combine
	}

	public override func isEqual(_ object: Any?) -> Bool {
		guard let object = object as? Email else {
			return false
		}
		return self.address == object.address
	}

	convenience init?(json: JSON) {
		let preferred = false
		guard let address = json["address"].string else { // preferred is not supported yet on mobile api
			return nil
		}
		self.init(address: address, preferred: preferred)
	}

	public init(address: String, preferred: Bool) {
		self.address = address
		self.preferred = preferred
	}

	required public init?(coder aDecoder: NSCoder) {
		address = aDecoder.decodeObject(forKey: "address") as! String
		preferred = aDecoder.decodeBool(forKey: "preferred")
	}

	public func encode(with aCoder: NSCoder) {
		aCoder.encode(address, forKey: "address")
		aCoder.encode(preferred, forKey: "preferred")
	}
}

public class UserIdentity: NSObject {
	public let phones: [String]?
	public let emails: [String]?
	public let externalUserId: String?

	/// Default initializer. The object won't be initialized if all three arguments are nil/empty. Unique user identity must have at least one value.
	public init?(phones: [String]?, emails: [String]?, externalUserId: String?) {
		if (phones == nil || phones!.isEmpty) && (emails == nil || emails!.isEmpty) && externalUserId == nil {
			return nil
		}
		self.phones = phones
		self.emails = emails
		self.externalUserId = externalUserId
	}
}

public class UserAttributes: NSObject, DictionaryRepresentable {
	/// The user's first name. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var firstName: String?

	/// A user's middle name. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var middleName: String?

	/// A user's last name. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var lastName: String?

	/// A user's tags. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var tags: Array<String>?

	/// A user's gender. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var gender: Gender?

	/// A user's birthday. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var birthday: Date?

	/// Returns user's custom data. Arbitrary attributes that are related to a particular user. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var customAttributes: [String: AttributeType]?

	public init(firstName: String?
		,middleName: String?
		,lastName: String?
		,tags: Array<String>?
		,gender: Gender?
		,birthday: Date?
		,customAttributes: [String: AttributeType]?) {

		self.firstName = firstName
		self.middleName = middleName
		self.lastName = lastName
		self.tags = tags
		self.gender = gender
		self.birthday = birthday
		self.customAttributes = customAttributes
	}

	// must be extracted to cordova plugin srcs
	public required convenience init?(dictRepresentation dict: DictionaryRepresentation) {
		let value = JSON.init(dict)
		self.init(firstName: value["firstName"].string,
				  middleName: value["middleName"].string,
				  lastName: value["lastName"].string,
				  tags: (value["tags"].arrayObject as? [String]),
				  gender: value["gender"].string.ifSome({ Gender.make(with: $0) }),
				  birthday: value["birthday"].string.ifSome({ DateStaticFormatters.ContactsServiceDateFormatter.date(from: $0) }),
				  customAttributes: value["customAttributes"].dictionary?.decodeCustomAttributesJSON)
	}

	// must be extracted to cordova plugin srcs
	public var dictionaryRepresentation: DictionaryRepresentation {
		return [
			"firstName"				: firstName as Any,
			"middleName"			: middleName as Any,
			"lastName"				: lastName as Any,
			"tags"					: tags as Any,
			"gender"				: gender?.name as Any,
			"birthday"				: birthday.ifSome({ DateStaticFormatters.ContactsServiceDateFormatter.string(from: $0) }) as Any,
			"customAttributes"		: UserDataMapper.makeCustomAttributesPayload(customAttributes, attributesSet: nil) as Any
		]
	}
}

public final class User: UserAttributes, JSONDecodable {
	/// The user's id you can provide in order to link your own unique user identifier with Mobile Messaging user id, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var externalUserId: String?

	/// User's phone numbers. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var phones: Array<String>?

	/// User's email addresses. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var emails: Array<String>?

	/// All installations personalized with the user
	public let installations: Array<Installation>?

	convenience init(userIdentity: UserIdentity, userAttributes: UserAttributes?) {
		self.init(externalUserId: userIdentity.externalUserId, firstName: userAttributes?.firstName, middleName: userAttributes?.middleName, lastName: userAttributes?.lastName, phones: userIdentity.phones, emails: userIdentity.emails, tags: userAttributes?.tags, gender: userAttributes?.gender, birthday: userAttributes?.birthday, customAttributes: userAttributes?.customAttributes, installations: nil)
	}

	init(externalUserId: String?
		,firstName: String?
		,middleName: String?
		,lastName: String?
		,phones: Array<String>?
		,emails: Array<String>?
		,tags: Array<String>?
		,gender: Gender?
		,birthday: Date?
		,customAttributes: [String: AttributeType]?
		,installations: Array<Installation>?) {

		self.installations = installations
		self.externalUserId = externalUserId
		self.phones = phones
		self.emails = emails

		super.init(firstName: firstName, middleName: middleName, lastName: lastName, tags: tags, gender: gender, birthday: birthday, customAttributes: customAttributes)
	}

	convenience init?(json value: JSON) {
		self.init(externalUserId: value[Attributes.externalUserId.requestPayloadKey].string,
				  firstName: value[Attributes.firstName.requestPayloadKey].string,
				  middleName: value[Attributes.middleName.requestPayloadKey].string,
				  lastName: value[Attributes.lastName.requestPayloadKey].string,
				  phones: value[Attributes.phones.requestPayloadKey].array?.compactMap({ return Phone(json: $0)?.number }),
				  emails: value[Attributes.emails.requestPayloadKey].array?.compactMap({ return Email(json: $0)?.address }),
				  tags: (value[Attributes.tags.requestPayloadKey].arrayObject as? [String]),
				  gender: value[Attributes.gender.requestPayloadKey].string.ifSome({ Gender.make(with: $0) }),
				  birthday: value[Attributes.birthday.requestPayloadKey].string.ifSome({ DateStaticFormatters.ContactsServiceDateFormatter.date(from: $0) }),
				  customAttributes: value[Attributes.customUserAttributes.requestPayloadKey].dictionary?.decodeCustomAttributesJSON,
				  installations: value[Attributes.instances.requestPayloadKey].array?.compactMap({ Installation(json: $0) }))
	}

	// must be extracted to cordova plugin srcs
	public required convenience init?(dictRepresentation dict: DictionaryRepresentation) {
		let value = JSON.init(dict)
		self.init(externalUserId: value["externalUserId"].string,
				  firstName: value["firstName"].string,
				  middleName: value["middleName"].string,
				  lastName: value["lastName"].string,
				  phones: value["phones"].array?.compactMap({ return Phone(json: $0)?.number }),
				  emails: value["emails"].array?.compactMap({ return Email(json: $0)?.address }),
				  tags: (value["tags"].arrayObject as? [String]),
				  gender: value["gender"].string.ifSome({ Gender.make(with: $0) }),
				  birthday: value["birthday"].string.ifSome({ DateStaticFormatters.ContactsServiceDateFormatter.date(from: $0) }),
				  customAttributes: value["customAttributes"].dictionary?.decodeCustomAttributesJSON,
				  installations: value["installations"].array?.compactMap({ Installation(json: $0) }))
	}

	// must be extracted to cordova plugin srcs
	public override var dictionaryRepresentation: DictionaryRepresentation {
		var ret = super.dictionaryRepresentation
		ret["externalUserId"] = externalUserId
		ret["phones"] = phones
		ret["emails"] = emails
		ret["installations"] = installations?.map({ return $0.dictionaryRepresentation })
		return ret
	}

	public override func isEqual(_ object: Any?) -> Bool {
		guard let object = object as? User else {
			return false
		}

		return externalUserId == object.externalUserId &&
			firstName == object.firstName &&
			middleName == object.middleName &&
			lastName == object.lastName &&
			phones == object.phones &&
			emails == object.emails &&
			tags == object.tags &&
			gender == object.gender &&
			contactsServiceDateEqual(birthday, object.birthday) &&
			customAttributes == object.customAttributes &&
			installations == object.installations
	}
}
