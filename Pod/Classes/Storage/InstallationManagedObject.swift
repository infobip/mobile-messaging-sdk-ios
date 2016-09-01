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
	
	static var userData: Int {
		return	SyncableAttributes.CustomUserData.integerValue | SyncableAttributes.PredefinedUserData.integerValue | SyncableAttributes.ExternalUserId.integerValue
	}
	
	var integerValue: Int {
		switch self {
		case .DeviceToken:
			return 1 << 0
		case .CustomUserData:
			return 1 << 1
		case .PredefinedUserData:
			return 1 << 2
		case .ExternalUserId:
			return 1 << 3
		}
	}
}

struct SyncableAttributesSet: OptionSet {
	let rawValue : Int
	init(rawValue: Int) { self.rawValue = rawValue }
	
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
			}
		}
		return nil
	}
	static let deviceToken	= SyncableAttributesSet(rawValue: SyncableAttributes.DeviceToken.integerValue)
	static let customUserData = SyncableAttributesSet(rawValue: SyncableAttributes.CustomUserData.integerValue)
	static let predefinedUserData = SyncableAttributesSet(rawValue: SyncableAttributes.PredefinedUserData.integerValue)
	static let externalUserId = SyncableAttributesSet(rawValue: SyncableAttributes.ExternalUserId.integerValue)
	
	static let userData = SyncableAttributesSet(rawValue: SyncableAttributes.userData)
}


final class InstallationManagedObject: NSManagedObject, Fetchable {

	override func didChangeValue(forKey key: String) {
		super.didChangeValue(forKey: key)
		setDirtyAttribute(attrName: key)
    }
	
    func setDeviceTokenIfDifferent(token: String?) {
        setValueIfDifferent(value: token, forKey: SyncableAttributes.DeviceToken.rawValue)
    }

	var dirtyAttributesSet: SyncableAttributesSet {
		return SyncableAttributesSet(rawValue: dirtyAttributes.intValue)
	}

	func resetDirtyRegistration() {
		resetDirtyAttribute(attributes: SyncableAttributesSet.deviceToken)
	}

	func resetDirtyAttribute(attributes: SyncableAttributesSet) {
		var newSet = dirtyAttributesSet
		newSet.remove(attributes)
		dirtyAttributes = NSNumber(value: newSet.rawValue)
	}
	
	private func setDirtyAttribute(attrName: String) {
		if let dirtyAttribute = SyncableAttributesSet.withAttribute(name: attrName) {
			var updatedSet = dirtyAttributesSet
			updatedSet.insert(dirtyAttribute)
			dirtyAttributes = NSNumber(value: updatedSet.rawValue)
		}
	}
	
	func setValueIfDifferent<Value: Equatable>(value: Value?, forKey key: String) {
		var isDifferent: Bool
		if let currentValue = self.value(forKey: key) as? Value? {
			isDifferent = value == nil ? true : currentValue != value
		} else {
			isDifferent = value != nil
		}
		if isDifferent {
			super.setValue(value, forKey: key)
		}
    }
	
	func setValueIfDifferent<Value: Any>(value: Value?, forKey key: String) {
		var isDifferent: Bool
		if let currentValue = self.value(forKey: key) as? AnyObject {
			isDifferent = value == nil ? true : !currentValue.isEqual(value!)
		} else {
			isDifferent = value != nil
		}
		if isDifferent {
			super.setValue(value, forKey: key)
		}
	}
}
