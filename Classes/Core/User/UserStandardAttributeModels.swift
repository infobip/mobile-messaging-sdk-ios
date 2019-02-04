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

final class Phone: NSObject, NSCoding, JSONDecodable, DictionaryRepresentable {
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
		return self.number == object.number // preferred is not supported yet on mobile api
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

final class Email: NSObject, NSCoding, JSONDecodable, DictionaryRepresentable {
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
			"customAttributes"		: UserDataMapper.makeCustomAttributesPayload(customAttributes) as Any
		]
	}
}

public final class User: UserAttributes, JSONDecodable, NSCoding, NSCopying, Archivable {
	var version: Int = 0
	static var currentPath = getDocumentsDirectory(filename: "user")
	static var dirtyPath = getDocumentsDirectory(filename: "dirty-user")
	static var cached = ThreadSafeDict<User>()
	static var empty: User {
		return User(externalUserId: nil, firstName: nil, middleName: nil, lastName: nil, phones: nil, emails: nil, tags: nil, gender: nil, birthday: nil, customAttributes: nil, installations: nil)
	}
	func removeSensitiveData() {
		if MobileMessaging.privacySettings.userDataPersistingDisabled == true {
			self.firstName = nil
			self.middleName = nil
			self.lastName = nil
			self.gender = nil
			self.emails = nil
			self.phones = nil
			self.customAttributes = nil
			self.birthday = nil
			self.externalUserId = nil
		}
	}
	func handleCurrentChanges(old: User, new: User) {
		// nothing to do
	}
	func handleDirtyChanges(old: User, new: User) {
		// nothing to do
	}

	//
	static var delta: [String: Any] {
		guard let currentUserDict = MobileMessaging.sharedInstance?.currentUser().dictionaryRepresentation, let dirtyUserDict = MobileMessaging.sharedInstance?.dirtyUser().dictionaryRepresentation else {
			return [:]
		}
		return deltaDict(currentUserDict, dirtyUserDict)
	}

	/// The user's id you can provide in order to link your own unique user identifier with Mobile Messaging user id, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var externalUserId: String?

	/// User's phone numbers. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var phones: Array<String>? {
		set {
			phonesObjects = newValue?.map({ return Phone(number: $0, preferred: false) })
		}
		get {
			return phonesObjects?.map({ return $0.number })
		}
	}
	var phonesObjects: Array<Phone>?

	/// User's email addresses. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var emails: Array<String>? {
		set {
			emailsObjects = newValue?.map({ return Email(address: $0, preferred: false) })
		}
		get {
			return emailsObjects?.map({ return $0.address })
		}
	}
	var emailsObjects: Array<Email>?

	/// All installations personalized with the user
	public internal(set) var installations: Array<Installation>?

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

		super.init(firstName: firstName, middleName: middleName, lastName: lastName, tags: tags, gender: gender, birthday: birthday, customAttributes: customAttributes)
		self.installations = installations
		self.externalUserId = externalUserId
		self.phones = phones
		self.emails = emails
	}

	convenience init?(json value: JSON) {
		self.init(externalUserId: value[Attributes.externalUserId.rawValue].string,
				  firstName: value[Attributes.firstName.rawValue].string,
				  middleName: value[Attributes.middleName.rawValue].string,
				  lastName: value[Attributes.lastName.rawValue].string,
				  phones: value[Attributes.phones.rawValue].array?.compactMap({ return Phone(json: $0)?.number }),
				  emails: value[Attributes.emails.rawValue].array?.compactMap({ return Email(json: $0)?.address }),
				  tags: (value[Attributes.tags.rawValue].arrayObject as? [String]),
				  gender: value[Attributes.gender.rawValue].string.ifSome({ Gender.make(with: $0) }),
				  birthday: value[Attributes.birthday.rawValue].string.ifSome({ DateStaticFormatters.ContactsServiceDateFormatter.date(from: $0) }),
				  customAttributes: value[Attributes.customAttributes.rawValue].dictionary?.decodeCustomAttributesJSON,
				  installations: value[Attributes.instances.rawValue].array?.compactMap({ Installation(json: $0) }))
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

	// must be extracted to cordova plugin srcs, only public atts exposed
	public override var dictionaryRepresentation: DictionaryRepresentation {
		var ret = super.dictionaryRepresentation
		ret["externalUserId"] = externalUserId as Any
		ret["phones"] = phones as Any
		ret["emails"] = emails as Any
		ret["installations"] = installations?.map({ return $0.dictionaryRepresentation }) as Any
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

	required public init?(coder aDecoder: NSCoder) {
		super.init(firstName: aDecoder.decodeObject(forKey: "firstName") as? String,
				   middleName: aDecoder.decodeObject(forKey: "middleName") as? String,
				   lastName: aDecoder.decodeObject(forKey: "lastName") as? String,
				   tags: aDecoder.decodeObject(forKey: "tags") as? Array<String>,
				   gender: Gender(rawValue: (aDecoder.decodeObject(forKey: "gender") as? Int) ?? 999) ,
				   birthday: aDecoder.decodeObject(forKey: "birthday") as? Date,
				   customAttributes: aDecoder.decodeObject(forKey: "customAttributes") as? [String: AttributeType])
		externalUserId = aDecoder.decodeObject(forKey: "externalUserId") as? String
		phonesObjects = aDecoder.decodeObject(forKey: "phones") as? Array<Phone>
		emailsObjects = aDecoder.decodeObject(forKey: "emails") as? Array<Email>
		installations = aDecoder.decodeObject(forKey: "installations") as? Array<Installation>
	}

	public func encode(with aCoder: NSCoder) {
		aCoder.encode(externalUserId, forKey: "externalUserId")
		aCoder.encode(firstName, forKey: "firstName")
		aCoder.encode(middleName, forKey: "middleName")
		aCoder.encode(lastName, forKey: "lastName")
		aCoder.encode(phonesObjects, forKey: "phones")
		aCoder.encode(emailsObjects, forKey: "emails")
		aCoder.encode(tags, forKey: "tags")
		aCoder.encode(gender?.rawValue, forKey: "gender")
		aCoder.encode(birthday, forKey: "birthday")
		aCoder.encode(customAttributes, forKey: "customAttributes")
		aCoder.encode(installations, forKey: "installations")
	}

	public func copy(with zone: NSZone? = nil) -> Any {
		return User(externalUserId: externalUserId, firstName: firstName, middleName: middleName, lastName: lastName, phones: phones, emails: emails, tags: tags, gender: gender, birthday: birthday, customAttributes: customAttributes, installations: installations)
	}
}
