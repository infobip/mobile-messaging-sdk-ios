//
//  InstallationManagedObject.swift
//  MobileMessaging
//
//  Created by Andrey K. on 18/02/16.
//  
//

import Foundation
import CoreData

enum Attributes: String {
	
	case deviceToken		= "deviceToken"
	case customUserData		= "customUserData"
	case predefinedUserData = "predefinedUserData"
	case externalUserId		= "externalUserId"
	case registrationEnabled = "isRegistrationEnabled"
	case applicationCode	= "applicationCode"
	case badgeNumber		= "badgeNumber"
	case systemDataHash		= "systemDataHash"
	case location			= "location"
	case internalUserId		= "internalUserId"
	
	static var userDataAttributes: Int32 {
		return	Attributes.customUserData.integerValue |
			Attributes.predefinedUserData.integerValue |
			Attributes.externalUserId.integerValue
	}
	
	static var registrationAttributes: Int32 {
		return	Attributes.deviceToken.integerValue |
			Attributes.registrationEnabled.integerValue
	}
	
	var integerValue: Int32 {
		switch self {
		case .deviceToken:
			return 1 << 0
		case .customUserData:
			return 1 << 1
		case .predefinedUserData:
			return 1 << 2
		case .externalUserId:
			return 1 << 3
		case .registrationEnabled:
			return 1 << 4
		case .applicationCode:
			return 1 << 5
		case .badgeNumber:
			return 1 << 6
		case .systemDataHash:
			return 1 << 7
		case .location:
			return 1 << 8
		case .internalUserId:
			return 1 << 9
		}
	}
	
	var asSet: AttributesSet {
		return AttributesSet(rawValue: integerValue)
	}
}

struct AttributesSet: OptionSet {
	let rawValue : Int32
	init(rawValue: Int32) { self.rawValue = rawValue }
	
	static func withAttribute(name: String) -> AttributesSet? {
		if let attr = Attributes(rawValue: name) {
			switch attr {
			case .deviceToken:
				return AttributesSet.deviceToken
			case .predefinedUserData:
				return AttributesSet.predefinedUserData
			case .customUserData:
				return AttributesSet.customUserData
			case .externalUserId:
				return AttributesSet.externalUserId
			case .registrationEnabled:
				return AttributesSet.isRegistrationEnabled
			case .applicationCode:
				return AttributesSet.applicationCode
			case .badgeNumber:
				return AttributesSet.badgeNumber
			case .systemDataHash:
				return AttributesSet.systemDataHash
			case .location:
				return AttributesSet.location
			case .internalUserId:
				return AttributesSet.internalUserId
			}
		}
		return nil
	}
	static let deviceToken				= Attributes.deviceToken.asSet
	static let isRegistrationEnabled	= Attributes.registrationEnabled.asSet
	static let customUserData			= Attributes.customUserData.asSet
	static let predefinedUserData		= Attributes.predefinedUserData.asSet
	static let externalUserId			= Attributes.externalUserId.asSet
	static let applicationCode			= Attributes.applicationCode.asSet
	static let badgeNumber				= Attributes.badgeNumber.asSet
	static let systemDataHash			= Attributes.systemDataHash.asSet
	static let location					= Attributes.location.asSet
	static let internalUserId			= Attributes.internalUserId.asSet
	
	static let userData					= AttributesSet(rawValue: Attributes.userDataAttributes)
	static let registrationAttributes	= AttributesSet(rawValue: Attributes.registrationAttributes)
}


final class InstallationManagedObject: NSManagedObject, Fetchable {

	override func didChangeValue(forKey key: String) {
		super.didChangeValue(forKey: key)
		setDirtyAttribute(attrName: key)
    }

	var dirtyAttributesSet: AttributesSet {
		return AttributesSet(rawValue: dirtyAttributes)
	}
	
	func resetDirtyAttribute(attributes: AttributesSet) {
		var newSet = dirtyAttributesSet
		newSet.remove(attributes)
		dirtyAttributes = newSet.rawValue
	}

	private func setDirtyAttribute(attrName: String) {
		if let dirtyAttribute = AttributesSet.withAttribute(name: attrName) {
			var updatedSet = dirtyAttributesSet
			updatedSet.insert(dirtyAttribute)
			dirtyAttributes = updatedSet.rawValue
		}
	}
	
	func setValueIfDifferent<Value: Equatable>(_ value: Value?, forKey key: String) {
		var isDifferent: Bool
		if let currentValue = self.value(forKey: key) as? Value {
			isDifferent = value == nil ? true : currentValue != value!
		} else {
			isDifferent = value != nil
		}
		if isDifferent {
			super.setValue(value, forKey: key)
		}
    }
	
	func setValueIfDifferent(_ value: Dictionary<AnyHashable, UserDataFoundationTypes>?, forKey key: String) {
		var isDifferent: Bool
		if let currentValue = self.value(forKey: key) as? Dictionary<AnyHashable, UserDataFoundationTypes> {
			isDifferent = value == nil ? true : currentValue != value!
		} else {
			isDifferent = value != nil
		}
		if isDifferent {
			super.setValue(value, forKey: key)
		}
	}
}
