//
//  CustomAttributeModels.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 01/11/2018.
//

import Foundation

public typealias MMEventPropertyType = MMAttributeType
@objc public protocol MMAttributeType: AnyObject {}
extension NSDate: MMAttributeType {}
extension NSNumber: MMAttributeType {}
extension NSString: MMAttributeType {}
extension NSNull: MMAttributeType {}
extension MMDateTime: MMAttributeType{}
extension NSArray: MMAttributeType {}

@objcMembers public final class MMDateTime: NSObject, NSSecureCoding {
    public static var supportsSecureCoding = true
	public let date: NSDate
	public init(date: Date) {
		self.date = date as NSDate
	}
	public required init(coder aDecoder: NSCoder) {
        date = aDecoder.decodeObject(of: NSDate.self, forKey: "date")!
	}
	public func encode(with aCoder: NSCoder) {
		aCoder.encode(date, forKey: "date")
	}
	public override func isEqual(_ object: Any?) -> Bool {
		guard let object = object as? MMDateTime else {
			return false
		}
		return self.date.isEqual(to: object.date as Date)
	}
}

extension Dictionary where Value == MMAttributeType, Key == String {
	func assertCustomAttributesValid() {
        assert(self.validateListObjectsContainOnlySupportedTypes(), "One of the objects in list has unsupported field datatype. Check documentation https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Users-and-installations.")
		assert(self.validateListObjectsHaveTheSameStructure(), "One of the object in list has different model. Check documentation https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Users-and-installations.")
	}
	
	func validateListObjectsContainOnlySupportedTypes() -> Bool {
		let containsArrayWithUnsupportedElements = self.values.filter({ $0 is NSArray }).contains(where: { !($0 is Array<[String: MMAttributeType]>) })
		return !containsArrayWithUnsupportedElements
	}
	
	func validateListObjectsHaveTheSameStructure() -> Bool {
		return self.values.filter({ $0 is NSArray }).reduce(true) { (result, listOfDicts) -> Bool in
			if let listOfDicts = listOfDicts as? Array<[String: Any]> {
				if let first = listOfDicts.first {
					return result && listOfDicts.dropFirst().reduce(true) { (r, dict) -> Bool in
						return r && first.count == dict.count && dict.reduce(true) { (r2, kv) -> Bool in
							if let v = first[kv.key] {
								let typesSame = type(of: v) == type(of: kv.value)
								return r2 && typesSame
							} else {
								return false
							}
						}
					}
				} else {
					return result && true
				}
			} else {
				return false
			}
		}
	}
}

extension Dictionary where Value == JSON, Key == String {
	var decodeCustomAttributesJSON: [String : MMAttributeType] {
		return self.reduce([String: MMAttributeType](), { (result, pair) -> [String: MMAttributeType] in
			if var value = pair.value.rawValue as? MMAttributeType {
				if value is NSNull {
					return result
				}
				if let stringValue = value as? String, stringValue.prefix(4).isNumber {
					if let date = DateStaticFormatters.ContactsServiceDateFormatter.date(from: stringValue) {
						value = date as NSDate
					} else if let date = DateStaticFormatters.ISO8601SecondsFormatter.date(from: stringValue) {
						value = MMDateTime(date: date)
					}
				}
				return result + [pair.key: value]
			} else {
				return result
			}
		})
	}
	
	var decodeCustomEventPropertiesJSON: [String : MMAttributeType] {
		return self.reduce([String: MMAttributeType](), { (result, pair) -> [String: MMAttributeType] in
			if var value = pair.value.rawValue as? MMAttributeType {
				if value is NSNull {
					return result
				}
				if let stringValue = value as? String, stringValue.prefix(4).isNumber, let date = DateStaticFormatters.ContactsServiceDateFormatter.date(from: stringValue) {
					value = date as NSDate
				}
				return result + [pair.key: value]
			} else {
				return result
			}
		})
	}
}
