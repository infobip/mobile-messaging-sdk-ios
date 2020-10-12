//
//  UserCustomAttributeModels.swift
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
extension NSArray: AttributeType {}

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
