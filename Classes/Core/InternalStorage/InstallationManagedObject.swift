//
//  InstallationManagedObject.swift
//  MobileMessaging
//
//  Created by Andrey K. on 18/02/16.
//  
//

import Foundation
import CoreData

final class InstallationManagedObject: NSManagedObject, FetchableResult {

	var dirtyAttsSet: AttributesSet {
		if let dirtyAttributesString = dirtyAttributesString {
			let substrings: [String] = dirtyAttributesString.split(separator: ",").map(String.init)
			let atts = substrings.compactMap({ s in return Attributes.fromString(s) })
			return Set(atts)
		} else {
			return Set()
		}
	}

	var depersonalizeStatus: SuccessPending {
		return SuccessPending(rawValue: Int(self.logoutStatusValue)) ?? .undefined
	}
	
	func resetDirtyAttribute(attributes: Attributes) {
		var newSet = dirtyAttsSet
		newSet.removeAttributes([attributes])
		setValue(newSet.map({ $0.rawValue }).joined(separator: ","), forKey: "dirtyAttributesString")
	}

	private func setDirtyAttribute(key: String) {
		if let att = Attributes.fromString(key) {
			setPrimitiveValue(dirtyAttsSet.union([att]).map({ $0.rawValue }).joined(separator: ","), forKey: "dirtyAttributesString")
		}
	}

	override func setValue(_ value: Any?, forUndefinedKey key: String) {
		if let prefix = key.split(separator: ".").first {
			switch String(prefix) {
			case Attributes.customUserAttributes.databaseKey, Attributes.customInstanceAttributes.databaseKey:
				setValue(value, forKey: String(prefix))
				setDirtyAttribute(key: key)
			default: break
			}
		}
	}

	override func willSave() {
		let atts = Set(changedValues().keys).subtracting(["dirtyAttributesString"])
		atts.forEach { (k) in
			setDirtyAttribute(key: k)
		}
		super.willSave()

		if atts.contains("pushRegId") {
			UserEventsManager.postRegUpdatedEvent(self.pushRegId)
		}

		if atts.contains("regEnabled") {
			MobileMessaging.sharedInstance?.updateRegistrationEnabledSubservicesStatus()
		}

		if atts.contains("logoutStatusValue") {
			MMLogDebug("[Installation management] setting new depersonalize status: \(self.logoutStatusValue)")
			MobileMessaging.sharedInstance?.updateDepersonalizeStatusForSubservices()
		}
	}
}
