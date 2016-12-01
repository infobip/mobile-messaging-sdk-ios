//
//  InstallationManagedObject.swift
//  MobileMessaging
//
//  Created by Andrey K. on 18/02/16.
//  
//

import Foundation
import CoreData

enum SyncableAttributes: String {
	
	case DeviceToken = "deviceToken"
	case CustomUserData = "customUserData"
	case PredefinedUserData = "predefinedUserData"
	case ExternalUserId = "externalUserId"
	case RegistrationEnabled = "isRegistrationEnabled"
	
	static var userData: Int32 {
		return	SyncableAttributes.CustomUserData.integerValue | SyncableAttributes.PredefinedUserData.integerValue | SyncableAttributes.ExternalUserId.integerValue
	}
	
	var integerValue: Int32 {
		switch self {
		case .DeviceToken:
			return 1 << 0
		case .CustomUserData:
			return 1 << 1
		case .PredefinedUserData:
			return 1 << 2
		case .ExternalUserId:
			return 1 << 3
		case .RegistrationEnabled:
			return 1 << 4
		}
	}
}

struct SyncableAttributesSet: OptionSet {
	let rawValue : Int32
	init(rawValue: Int32) { self.rawValue = rawValue }
	
	static func withAttribute(name: String) -> SyncableAttributesSet? {
		if let attr = SyncableAttributes(rawValue: name) {
			switch attr {
			case .DeviceToken:
				return SyncableAttributesSet.deviceToken
			case .PredefinedUserData:
				return SyncableAttributesSet.predefinedUserData
			case .CustomUserData:
				return SyncableAttributesSet.customUserData
			case .ExternalUserId:
				return SyncableAttributesSet.externalUserId
			case .RegistrationEnabled:
				return SyncableAttributesSet.isRegistrationEnabled
			}
		}
		return nil
	}
	static let deviceToken	= SyncableAttributesSet(rawValue: SyncableAttributes.DeviceToken.integerValue)
	static let isRegistrationEnabled	= SyncableAttributesSet(rawValue: SyncableAttributes.RegistrationEnabled.integerValue)
	static let customUserData = SyncableAttributesSet(rawValue: SyncableAttributes.CustomUserData.integerValue)
	static let predefinedUserData = SyncableAttributesSet(rawValue: SyncableAttributes.PredefinedUserData.integerValue)
	static let externalUserId = SyncableAttributesSet(rawValue: SyncableAttributes.ExternalUserId.integerValue)
	
	static let userData = SyncableAttributesSet(rawValue: SyncableAttributes.userData)
	
	static let registrationAttributes = SyncableAttributesSet([SyncableAttributesSet.isRegistrationEnabled, SyncableAttributesSet.deviceToken])
}


final class InstallationManagedObject: NSManagedObject, Fetchable {

	override func didChangeValue(forKey key: String) {
		super.didChangeValue(forKey: key)
		setDirtyAttribute(attrName: key)
    }
	
    func setDeviceTokenIfDifferent(token: String?) {
        setValueIfDifferent(token, forKey: SyncableAttributes.DeviceToken.rawValue)
    }
	
	func setRegistrationEnabledIfDifferent(flag: Bool) {
		setValueIfDifferent(flag, forKey: SyncableAttributes.RegistrationEnabled.rawValue)
	}

	var dirtyAttributesSet: SyncableAttributesSet {
		return SyncableAttributesSet(rawValue: dirtyAttributes)
	}

	func resetDirtyRegistration() {
		resetDirtyAttribute(attributes: SyncableAttributesSet.registrationAttributes)
	}

	func resetDirtyAttribute(attributes: SyncableAttributesSet) {
		var newSet = dirtyAttributesSet
		newSet.remove(attributes)
		dirtyAttributes = newSet.rawValue
	}
	
	private func setDirtyAttribute(attrName: String) {
		if let dirtyAttribute = SyncableAttributesSet.withAttribute(name: attrName) {
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
