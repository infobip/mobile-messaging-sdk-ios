//
//  UserStandardAttributeModels.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 29/11/2018.
//

import Foundation

@objc public enum MMGenderNonnull: Int {
	case Female
	case Male
	case Undefined

	var toGender: MMGender? {
		switch self {
		case .Female : return .Female
		case .Male : return .Male
		case .Undefined : return nil
		}
	}

	static func make(from gender: MMGender?) -> MMGenderNonnull {
		if let gender = gender {
			switch gender {
			case .Female: return .Female
			case .Male: return .Male
			}
		} else {
			return .Undefined
		}
	}
}

public enum MMGender: Int {
	case Female
	case Male

	public var name: String {
		switch self {
		case .Female : return "Female"
		case .Male : return "Male"
		}
	}

	static func make(with name: String) -> MMGender? {
		switch name {
		case "Female":
			return MMGender.Female
		case "Male":
			return MMGender.Male
		default:
			return nil
		}
	}
}


@objcMembers public final class MMPhone: NSObject, NSSecureCoding, JSONDecodable, DictionaryRepresentable {
    public static var supportsSecureCoding = true
	public let number: String
	public var preferred: Bool
	// more properties needed? ok but look at the code below first.

    required public init?(dictRepresentation dict: DictionaryRepresentation) {
		fatalError("init(dictRepresentation:) has not been implemented")
	}

    public var dictionaryRepresentation: DictionaryRepresentation {
		return ["number": number]
	}

	public override var hash: Int {
		return number.hashValue// ^ preferred.hashValue // use hasher combine
	}

	public override func isEqual(_ object: Any?) -> Bool {
		guard let object = object as? MMPhone else {
			return false
		}
		return self.number == object.number // preferred is not supported yet on mobile api
	}

    convenience public init?(json: JSON) {
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
        number = aDecoder.decodeObject(of: NSString.self, forKey: "number")! as String
		preferred = aDecoder.decodeBool(forKey: "preferred")
	}

	public func encode(with aCoder: NSCoder) {
		aCoder.encode(number, forKey: "number")
		aCoder.encode(preferred, forKey: "preferred")
	}
}

@objcMembers public final class MMEmail: NSObject, NSSecureCoding, JSONDecodable, DictionaryRepresentable {
    public static var supportsSecureCoding = true
	public let address: String
	public var preferred: Bool
	// more properties needed? ok but look at the code below first.

    required public init?(dictRepresentation dict: DictionaryRepresentation) {
		fatalError("init(dictRepresentation:) has not been implemented")
	}

    public var dictionaryRepresentation: DictionaryRepresentation {
		return ["address": address]
	}

	public override var hash: Int {
		return address.hashValue// ^ preferred.hashValue // use hasher combine
	}

	public override func isEqual(_ object: Any?) -> Bool {
		guard let object = object as? MMEmail else {
			return false
		}
		return self.address == object.address
	}

    convenience public init?(json: JSON) {
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
        address = aDecoder.decodeObject(of: NSString.self, forKey: "address")! as String
		preferred = aDecoder.decodeBool(forKey: "preferred")
	}

	public func encode(with aCoder: NSCoder) {
		aCoder.encode(address, forKey: "address")
		aCoder.encode(preferred, forKey: "preferred")
	}
}

@objcMembers public class MMUserIdentity: NSObject {
	public let phones: [String]?
	public let emails: [String]?
	public let externalUserId: String?

	/// Default initializer. The object won't be initialized if all three arguments are nil/empty. Unique user identity must have at least one value.
	@objc public init?(phones: [String]?, emails: [String]?, externalUserId: String?) {
		if (phones == nil || phones!.isEmpty) && (emails == nil || emails!.isEmpty) && externalUserId == nil {
			return nil
		}
		self.phones = phones
		self.emails = emails
		self.externalUserId = externalUserId
	}
}

@objcMembers public class MMUserAttributes: NSObject, DictionaryRepresentable {
	/// The user's first name. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var firstName: String?

	/// A user's middle name. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var middleName: String?

	/// A user's last name. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var lastName: String?

	/// A user's tags. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var tags: Set<String>?

	/// A user's gender. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var gender: MMGender?

	public var genderNonnull: MMGenderNonnull {
		set { gender = newValue.toGender }
		get { return MMGenderNonnull.make(from: gender) }
	}

	/// A user's birthday. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var birthday: Date?

	/// Returns user's custom data. Arbitrary attributes that are related to a particular user. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var customAttributes: [String: MMAttributeType]? {
		willSet {
			newValue?.assertCustomAttributesValid()
		}
	}

	convenience public init(firstName: String?
		,middleName: String?
		,lastName: String?
		,tags: Set<String>?
		,genderNonnull: MMGenderNonnull
		,birthday: Date?
		,customAttributes: [String: MMAttributeType]?) {

		self.init(firstName: firstName, middleName: middleName, lastName: lastName, tags: tags, gender: genderNonnull.toGender, birthday: birthday, customAttributes: customAttributes)
	}

	public init(firstName: String?
		,middleName: String?
		,lastName: String?
		,tags: Set<String>?
		,gender: MMGender?
		,birthday: Date?
		,customAttributes: [String: MMAttributeType]?) {

		self.firstName = firstName
		self.middleName = middleName
		self.lastName = lastName
		self.tags = tags
		self.gender = gender
		self.birthday = birthday
		self.customAttributes = customAttributes
	}

	public required convenience init?(dictRepresentation dict: DictionaryRepresentation) {
		let value = JSON.init(dict)
		self.init(firstName: value["firstName"].string,
				  middleName: value["middleName"].string,
				  lastName: value["lastName"].string,
				  tags: arrayToSet(arr: value["tags"].arrayObject as? [String]),
				  gender: value["gender"].string.ifSome({ MMGender.make(with: $0) }),
				  birthday: value["birthday"].string.ifSome({ DateStaticFormatters.ContactsServiceDateFormatter.date(from: $0) }),
				  customAttributes: value["customAttributes"].dictionary?.decodeCustomAttributesJSON)
	}

	public var dictionaryRepresentation: DictionaryRepresentation {
		return [
			"firstName"				: firstName as Any,
			"middleName"			: middleName as Any,
			"lastName"				: lastName as Any,
			"tags"					: tags?.asArray as Any,
			"gender"				: gender?.name as Any,
			"birthday"				: birthday.ifSome({ DateStaticFormatters.ContactsServiceDateFormatter.string(from: $0) }) as Any,
			"customAttributes"		: UserDataMapper.makeCustomAttributesPayload(customAttributes) as Any
		]
	}
}

@objcMembers public final class MMUser: MMUserAttributes, JSONDecodable, NSSecureCoding, NSCopying, Archivable {
    public static var supportsSecureCoding = true
    public var version: Int = 0
    public static var currentPath = getDocumentsDirectory(filename: "user")
    public static var dirtyPath = getDocumentsDirectory(filename: "dirty-user")
    public static var cached = ThreadSafeDict<MMUser>()
    public static var empty: MMUser {
		return MMUser(externalUserId: nil, firstName: nil, middleName: nil, lastName: nil, phones: nil, emails: nil, tags: nil, gender: nil, birthday: nil, customAttributes: nil, installations: nil)
	}
    public func removeSensitiveData() {
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
    public func handleCurrentChanges(old: MMUser, new: MMUser) {
		// nothing to do
	}
    public func handleDirtyChanges(old: MMUser, new: MMUser) {
		// nothing to do
	}

	//
	static var delta: [String: Any]? {
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
			phonesObjects = newValue?.map({ return MMPhone(number: $0, preferred: false) })
		}
		get {
			return phonesObjects?.map({ return $0.number })
		}
	}
	var phonesObjects: Array<MMPhone>?

	/// User's email addresses. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var emails: Array<String>? {
		set {
			emailsObjects = newValue?.map({ return MMEmail(address: $0, preferred: false) })
		}
		get {
			return emailsObjects?.map({ return $0.address })
		}
	}
	var emailsObjects: Array<MMEmail>?

	/// All installations personalized with the user
	public internal(set) var installations: Array<MMInstallation>?

	convenience init(userIdentity: MMUserIdentity, userAttributes: MMUserAttributes?) {
		self.init(externalUserId: userIdentity.externalUserId, firstName: userAttributes?.firstName, middleName: userAttributes?.middleName, lastName: userAttributes?.lastName, phones: userIdentity.phones, emails: userIdentity.emails, tags: userAttributes?.tags, gender: userAttributes?.gender, birthday: userAttributes?.birthday, customAttributes: userAttributes?.customAttributes, installations: nil)
	}

	init(externalUserId: String?
		,firstName: String?
		,middleName: String?
		,lastName: String?
		,phones: Array<String>?
		,emails: Array<String>?
		,tags: Set<String>?
		,gender: MMGender?
		,birthday: Date?
		,customAttributes: [String: MMAttributeType]?
		,installations: Array<MMInstallation>?) {

		super.init(firstName: firstName, middleName: middleName, lastName: lastName, tags: tags, gender: gender, birthday: birthday, customAttributes: customAttributes)
		self.installations = installations
		self.externalUserId = externalUserId
		self.phones = phones
		self.emails = emails
	}

    convenience public init?(json value: JSON) {
		self.init(externalUserId: value[Attributes.externalUserId.rawValue].string,
				  firstName: value[Attributes.firstName.rawValue].string,
				  middleName: value[Attributes.middleName.rawValue].string,
				  lastName: value[Attributes.lastName.rawValue].string,
				  phones: value[Attributes.phones.rawValue].array?.compactMap({ return MMPhone(json: $0)?.number }),
				  emails: value[Attributes.emails.rawValue].array?.compactMap({ return MMEmail(json: $0)?.address }),
				  tags: arrayToSet(arr: value[Attributes.tags.rawValue].arrayObject as? [String]),
				  gender: value[Attributes.gender.rawValue].string.ifSome({ MMGender.make(with: $0) }),
				  birthday: value[Attributes.birthday.rawValue].string.ifSome({ DateStaticFormatters.ContactsServiceDateFormatter.date(from: $0) }),
				  customAttributes: value[Attributes.customAttributes.rawValue].dictionary?.decodeCustomAttributesJSON,
				  installations: value[Attributes.instances.rawValue].array?.compactMap({ MMInstallation(json: $0) }))
	}

	// must be extracted to cordova plugin srcs
	public required convenience init?(dictRepresentation dict: DictionaryRepresentation) {
		let value = JSON.init(dict)
		self.init(externalUserId: value["externalUserId"].string,
				  firstName: value["firstName"].string,
				  middleName: value["middleName"].string,
				  lastName: value["lastName"].string,
				  phones: (value["phones"].arrayObject as? [String])?.compactMap({ return MMPhone(number: $0, preferred: false).number }),
				  emails: (value["emails"].arrayObject as? [String])?.compactMap({ return MMEmail(address: $0, preferred: false).address }),
				  tags: arrayToSet(arr: value["tags"].arrayObject as? [String]),
				  gender: value["gender"].string.ifSome({ MMGender.make(with: $0) }),
				  birthday: value["birthday"].string.ifSome({ DateStaticFormatters.ContactsServiceDateFormatter.date(from: $0) }),
				  customAttributes: value["customAttributes"].dictionary?.decodeCustomAttributesJSON,
				  installations: value["installations"].array?.compactMap({ MMInstallation(json: $0) }))
	}

	public override var dictionaryRepresentation: DictionaryRepresentation {
		var ret = super.dictionaryRepresentation
		ret["externalUserId"] = externalUserId as Any
		ret["phones"] = phones as Any
		ret["emails"] = emails as Any
		ret["installations"] = installations?.map({ return $0.dictionaryRepresentation }) as Any
		return ret
	}

	public override func isEqual(_ object: Any?) -> Bool {
		guard let object = object as? MMUser else {
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
		super.init(firstName: aDecoder.decodeObject(of: NSString.self, forKey: "firstName") as? String,
				   middleName: aDecoder.decodeObject(of: NSString.self, forKey: "middleName") as? String,
				   lastName: aDecoder.decodeObject(of: NSString.self, forKey: "lastName") as? String,
                   tags: arrayToSet(arr: aDecoder.decodeObject(of: [NSArray.self, NSSet.self], forKey: "tags") as? [String]),
				   gender: MMGender(rawValue: (aDecoder.decodeObject(forKey: "gender") as? Int) ?? 999) ,
                   birthday: aDecoder.decodeObject(of: NSDate.self, forKey: "birthday") as? Date,
                   customAttributes: aDecoder.decodeObject(of: [NSDictionary.self, NSArray.self, NSDate.self, MMDateTime.self, NSNull.self, NSString.self, NSNumber.self], forKey: "customAttributes") as? [String: MMAttributeType])
		externalUserId = aDecoder.decodeObject(of: NSString.self,  forKey: "externalUserId") as? String
        phonesObjects = aDecoder.decodeObject(of: [NSArray.self, MMPhone.self], forKey: "phones") as? Array<MMPhone>
        emailsObjects = aDecoder.decodeObject(of: [NSArray.self, MMEmail.self], forKey: "emails") as? Array<MMEmail>
        installations = aDecoder.decodeObject(of: [NSArray.self, MMInstallation.self], forKey: "installations") as? Array<MMInstallation>
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
		return MMUser(externalUserId: externalUserId, firstName: firstName, middleName: middleName, lastName: lastName, phones: phones, emails: emails, tags: tags, gender: gender, birthday: birthday, customAttributes: customAttributes, installations: installations)
	}
}
