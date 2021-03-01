//
//  CustomEventMapper.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 31.01.2020.
//

import Foundation

class CustomEventMapper {
	static func requestBody(events: [CustomEventObject]?) -> RequestBody? {
		guard let events = events, !events.isEmpty else {
			return nil
		}
		return ["events": events.map({ (customEvent) -> RequestBody in
			return [
				"definitionId": customEvent.definitionId,
				"properties": CustomEventMapper.makeCustomAttributesPayload(customEvent.payload as? [String: MMEventPropertyType]) as Any,
				"date": DateStaticFormatters.ISO8601SecondsFormatter.string(from: customEvent.eventDate)
				].compactMapValues { $0 }
		})
		]
	}

	static func requestBody(event: MMCustomEvent) -> RequestBody {
		return ["events": [
			[
				"definitionId": event.definitionId,
				"properties": CustomEventMapper.makeCustomAttributesPayload(event.properties) as Any ,
				"date": DateStaticFormatters.ISO8601SecondsFormatter.string(from: MobileMessaging.date.now)
				].compactMapValues { $0 }
			]
		]
	}

	class func makeCustomAttributesPayload(_ userCustomAttributes: [String: MMAttributeType]?) -> [String: Any]? {
		guard let userCustomAttributes = userCustomAttributes else {
			return nil
		}
		let filteredCustomAttributes: [String: MMAttributeType] = userCustomAttributes

		let ret = filteredCustomAttributes
			.reduce([String: Any](), { result, pair -> [String: Any] in
				var value: MMAttributeType = pair.value
				switch value {
				case (is NSNumber):
					break;
				case (is NSString):
					break;
				case (is Date):
					value = DateStaticFormatters.ISO8601SecondsFormatter.string(from: value as! Date) as NSString
				case (is NSNull):
					break;
				default:
					break;
				}
				return result + [pair.key: value]
			})
		return ret
	}
}
