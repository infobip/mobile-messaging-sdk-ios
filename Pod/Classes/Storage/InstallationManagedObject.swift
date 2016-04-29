//
//  InstallationManagedObject.swift
//  MobileMessaging
//
//  Created by Andrey K. on 18/02/16.
//  
//

import Foundation
import CoreData

struct SyncableAttributes: OptionSetType {
	let rawValue : Int
	init(rawValue: Int) { self.rawValue = rawValue }
	static func withName(attributeName: String) -> SyncableAttributes? {
		switch attributeName {
		case "deviceToken":
			return SyncableAttributes.deviceToken
		case "email":
			return SyncableAttributes.email
		case "msisdn":
			return SyncableAttributes.msisdn
        default:
            return nil
		}
	}
	static let deviceToken	= SyncableAttributes(rawValue: 1 << 0)
	static let email		= SyncableAttributes(rawValue: 1 << 1)
	static let msisdn		= SyncableAttributes(rawValue: 1 << 2)
}


class InstallationManagedObject: NSManagedObject {

	override func didChangeValueForKey(key: String) {
		super.didChangeValueForKey(key)
		setDirtyAttribute(key)
    }
    
    func setDeviceTokenIfDifferent(token: String?) {
        setValueIfDifferent(token, forKey: "deviceToken")
    }

	var dirtyAttributesSet: SyncableAttributes {
		return SyncableAttributes(rawValue: dirtyAttributes.integerValue)
	}

	func resetDirtyRegistration() {
		resetAttribute(SyncableAttributes.deviceToken)
	}

	private func resetAttribute(attributes: SyncableAttributes) {
		var newSet = dirtyAttributesSet
		newSet.remove(attributes)
		dirtyAttributes = newSet.rawValue
	}
	
	private func setDirtyAttribute(attrName: String) {
		if let newAttr = SyncableAttributes.withName(attrName) {
			var newSet = dirtyAttributesSet
			newSet.insert(newAttr)
			dirtyAttributes = newSet.rawValue
		}
	}
    
    func setValueIfDifferent(value: AnyObject?, forKey key: String) {
		var isDifferent: Bool
		if let currentValue = self.valueForKey(key) {
			isDifferent = value == nil ? true : !currentValue.isEqual(value!)
		} else {
			isDifferent = value != nil
		}
		if isDifferent {
			super.setValue(value, forKey: key)
		}
    }
}
