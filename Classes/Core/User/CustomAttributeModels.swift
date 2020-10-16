//
//  CustomAttributeModels.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 01/11/2018.
//

import Foundation

public typealias EventPropertyType = AttributeType
@objc public protocol AttributeType: AnyObject {}
extension NSDate: AttributeType {}
extension NSNumber: AttributeType {}
extension NSString: AttributeType {}
extension NSNull: AttributeType {}
extension DateTime: AttributeType{}
extension NSArray: AttributeType {}

@objcMembers public final class DateTime: NSObject, NSCoding {
	public let date: NSDate
	public init(date: Date) {
		self.date = date as NSDate
	}
	public required init(coder aDecoder: NSCoder) {
		date = aDecoder.decodeObject(forKey: "date") as! NSDate
	}
	public func encode(with aCoder: NSCoder) {
		aCoder.encode(date, forKey: "date")
	}
	public override func isEqual(_ object: Any?) -> Bool {
		guard let object = object as? DateTime else {
			return false
		}
		return self.date.isEqual(to: object.date as Date)
	}
}

extension Dictionary where Value == AttributeType, Key == String {
	func assertCustomAttributesValid() {
		assert(self.validateListObjectsContainOnlySupportedTypes(), "One of the objects in list has unsupported field datatype. Check documentation https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Users-and-installations.")
		assert(self.validateListObjectsHaveTheSameStructure(), "One of the object in list has different model. Check documentation https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Users-and-installations.")
	}
	
	func validateListObjectsContainOnlySupportedTypes() -> Bool {
		let containsArrayWithUnsupportedElements = self.values.filter({ $0 is NSArray }).contains(where: { !($0 is Array<[String: AttributeType]>) })
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
	var decodeCustomAttributesJSON: [String : AttributeType] {
		return self.reduce([String: AttributeType](), { (result, pair) -> [String: AttributeType] in
			if var value = pair.value.rawValue as? AttributeType {
				if value is NSNull {
					return result
				}
				if let stringValue = value as? String, stringValue.prefix(4).isNumber {
					if let date = DateStaticFormatters.ContactsServiceDateFormatter.date(from: stringValue) {
						value = date as NSDate
					} else if let date = DateStaticFormatters.ISO8601SecondsFormatter.date(from: stringValue) {
						value = DateTime(date: date)
					}
				}
				return result + [pair.key: value]
			} else {
				return result
			}
		})
	}
	
	var decodeCustomEventPropertiesJSON: [String : AttributeType] {
		return self.reduce([String: AttributeType](), { (result, pair) -> [String: AttributeType] in
			if var value = pair.value.rawValue as? AttributeType {
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
