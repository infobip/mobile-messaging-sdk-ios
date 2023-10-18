//
//  Transformer.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 09.10.2019.
//

import Foundation
import CoreLocation

@objc(DefaultTransformer)
class DefaultTransformer: ValueTransformer {
	override class func transformedValueClass() -> AnyClass {
		return NSData.self
	}

	override open func reverseTransformedValue(_ value: Any?) -> Any? {
		guard let value = value as? Data else {
			return nil
		}
        
        do {
            return try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSDictionary.self, NSArray.self, NSDate.self, CLLocation.self, MMDateTime.self, NSNull.self, NSString.self, NSNumber.self], from: value) //The following classes are used to archive data that is currently stored in database, including possible value types of the Dictionary<String, Any>.
        } catch {
            MMLogError("Unable to unarchive object with error: \(error)")
        }
        return nil
	}

	override class func allowsReverseTransformation() -> Bool {
        return true
    }

	override func transformedValue(_ value: Any?) -> Any? {
		guard let value = value else {
			return nil
		}
		return try? NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: true)
	}
}

//Not used in latest storage models
@objc(EmailTransformer)
class EmailTransformer: ValueTransformer {
	override class func transformedValueClass() -> AnyClass {
		return NSData.self
	}

	override open func reverseTransformedValue(_ value: Any?) -> Any? {
		guard let value = value as? Data else {
			return nil
		}
        return try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [MMEmail.self, NSArray.self], from: value)
	}

	override class func allowsReverseTransformation() -> Bool {
        return true
    }

	override func transformedValue(_ value: Any?) -> Any? {
		guard let value = value as? [MMEmail] else {
			return nil
		}
        return try? NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: true)
	}
}

//Not used in latest storage models
@objc(InstallationTransformer)
class InstallationTransformer: ValueTransformer {
	override class func transformedValueClass() -> AnyClass {
		return NSData.self
	}

	override open func reverseTransformedValue(_ value: Any?) -> Any? {
		guard let value = value as? Data else {
			return nil
		}
        return try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [MMInstallation.self, NSArray.self], from: value)
	}

	override class func allowsReverseTransformation() -> Bool {
        return true
    }

	override func transformedValue(_ value: Any?) -> Any? {
		guard let value = value as? [MMInstallation] else {
			return nil
		}
        return try? NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: true)
	}
}

//Not used in latest storage models
@objc(PhoneTransformer)
class PhoneTransformer: ValueTransformer {
	override class func transformedValueClass() -> AnyClass {
		return NSData.self
	}

	override open func reverseTransformedValue(_ value: Any?) -> Any? {
		guard let value = value as? Data else {
			return nil
		}
        return try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [MMPhone.self, NSArray.self], from: value)
	}

	override class func allowsReverseTransformation() -> Bool {
        return true
    }

	override func transformedValue(_ value: Any?) -> Any? {
		guard let value = value as? [MMPhone] else {
			return nil
		}
        return try? NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: true)
	}
}
