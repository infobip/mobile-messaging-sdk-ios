//
//  UserCustomAttributeModels.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 01/11/2018.
//

import Foundation

//public class AttributeType : NSObject {
//	enum FoundationType {
//		case Number, String, Null, Date
//	}
//	let foundationType: FoundationType
//	let value: AnyObject
//
//	init(date: NSDate) {
//		self.foundationType = .Date
//		self.value = date
//	}
//
//	init(number: NSNumber) {
//		self.foundationType = .Number
//		self.value = number
//	}
//
//	init(null: NSNull) {
//		self.foundationType = .Date
//		self.value = null
//	}
//
//	init(string: NSString) {
//		self.foundationType = .String
//		self.value = string
//	}
//
//	public override func isEqual(_ object: Any?) -> Bool {
//		guard let object = object as? AttributeType else {
//			return false
//		}
//		guard self.foundationType == object.foundationType else {
//			return false
//		}
//		switch self.foundationType {
//		case .Date:
//			return contactsServiceDateEqual((self.value as! Date), (object.value as! Date))
//		default:
//			return self.value.isEqual(object.value)
//		}
//	}
//}

public typealias EventPropertyType = AttributeType
@objc public protocol AttributeType: AnyObject {}
extension NSDate: AttributeType {}
extension NSNumber: AttributeType {}
extension NSString: AttributeType {}
extension NSNull: AttributeType {}

func ==(_ l: AttributeType, _r: AttributeType) -> Bool {
	return true
}

extension Dictionary where Value == JSON, Key == String {
	var decodeCustomAttributesJSON: [String : AttributeType] {
		return decodeJSON(attributes: self, withDateFormatter: DateStaticFormatters.ContactsServiceDateFormatter)
	}
	
	var decodeCustomEventPropertiesJSON: [String : AttributeType] {
		return decodeJSON(attributes: self, withDateFormatter: DateStaticFormatters.ISO8601SecondsFormatter)
	}
	
	func decodeJSON(attributes: [String : JSON], withDateFormatter dateFormatter: DateFormatter) -> [String : AttributeType] {
		return self.reduce([String: AttributeType](), { (result, pair) -> [String: AttributeType] in
			if var value = pair.value.rawValue as? AttributeType {
				if value is NSNull {
					return result
				}
				if let stringValue = value as? String, stringValue.prefix(1).isNumber {
					if let date = dateFormatter.date(from: stringValue) {
						value = date as NSDate
					}
				}
				return result + [pair.key: value]
			} else {
				return result
			}
		})
	}
}
