//
//  Transformer.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 09.10.2019.
//

import Foundation

@objc(DefaultTransformer)
class DefaultTransformer: ValueTransformer {
	override class func transformedValueClass() -> AnyClass {
		return NSData.self
	}

	override open func reverseTransformedValue(_ value: Any?) -> Any? {
		guard let value = value as? Data else {
			return nil
		}
		return try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(value)
	}

	override class func allowsReverseTransformation() -> Bool {
        return true
    }

	override func transformedValue(_ value: Any?) -> Any? {
		guard let value = value else {
			return nil
		}
		return try? NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: false)
	}
}

@objc(EmailTransformer)
class EmailTransformer: ValueTransformer {
	override class func transformedValueClass() -> AnyClass {
		return NSData.self
	}

	override open func reverseTransformedValue(_ value: Any?) -> Any? {
		guard let value = value as? Data else {
			return nil
		}
        return try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(value)
	}

	override class func allowsReverseTransformation() -> Bool {
        return true
    }

	override func transformedValue(_ value: Any?) -> Any? {
		guard let value = value as? [MMEmail] else {
			return nil
		}
        return try? NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: false)
	}
}

@objc(InstallationTransformer)
class InstallationTransformer: ValueTransformer {
	override class func transformedValueClass() -> AnyClass {
		return NSData.self
	}

	override open func reverseTransformedValue(_ value: Any?) -> Any? {
		guard let value = value as? Data else {
			return nil
		}
        return try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(value)
	}

	override class func allowsReverseTransformation() -> Bool {
        return true
    }

	override func transformedValue(_ value: Any?) -> Any? {
		guard let value = value as? [MMInstallation] else {
			return nil
		}
        return try? NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: false)
	}
}

@objc(PhoneTransformer)
class PhoneTransformer: ValueTransformer {
	override class func transformedValueClass() -> AnyClass {
		return NSData.self
	}

	override open func reverseTransformedValue(_ value: Any?) -> Any? {
		guard let value = value as? Data else {
			return nil
		}
        return try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(value)
	}

	override class func allowsReverseTransformation() -> Bool {
        return true
    }

	override func transformedValue(_ value: Any?) -> Any? {
		guard let value = value as? [MMPhone] else {
			return nil
		}
        return try? NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: false)
	}
}
