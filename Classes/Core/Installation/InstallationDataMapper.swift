//
//  InstallationDataMapper.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 14/01/2019.
//

import Foundation

class InstallationDataMapper {
	class func requestPayload(with installation: InstallationDataService, forAttributesSet attributesSet: Set<Attributes>) -> RequestBody? {
		let systemData: [String: Any] = attributesSet.contains(.systemDataHash) ? MobileMessaging.userAgent.systemData.requestPayload : [:]

		let attributesToSend: [String: Any] = attributesSet
			.intersection(Attributes.standardInstanceAttributesSet.union(Attributes.registrationAttributesSet) )
			.filter({$0 != .systemDataHash })
			.reduce([:], { (dict, att) -> [String: Any] in
				var dict = dict
				dict[att.requestPayloadKey] = installation.value(forAttribute: att) ?? NSNull()
				return dict
			})


		let customAttributes = makeCustomAttributesPayload(installation.customAttributes, attributesSet: attributesSet)

		var ret: [String: Any] = attributesToSend + systemData
		if let customAttributes = customAttributes, !customAttributes.isEmpty {
			ret[Attributes.customInstanceAttributes.requestPayloadKey] = customAttributes
		}

		return ret
	}

	//TODO: refactor duplication code
	class func makeCustomAttributesPayload(_ installationCustomAttributes: [String: AttributeType]?, attributesSet: AttributesSet?) -> [String: Any]? {
		guard let installationCustomAttributes = installationCustomAttributes else {
			return nil
		}
		let filteredCustomAttributes: [String: AttributeType]
		if let attributesSet = attributesSet {
			filteredCustomAttributes = installationCustomAttributes
				.filter({ pair -> Bool in
					attributesSet.contains(where: { (attribute) -> Bool in
						switch (attribute) {
						case .customInstanceAttribute(let key): return key == pair.key
						case .customInstanceAttributes: return true
						default: return false
						}
					})
				})
		} else {
			filteredCustomAttributes = installationCustomAttributes
		}

		return filteredCustomAttributes.reduce([String: Any](), { result, pair -> [String: Any] in
				var value: AttributeType = pair.value
				switch value {
				case (is NSNumber):
					break;
				case (is NSString):
					break;
				case (is Date):
					value = DateStaticFormatters.ContactsServiceDateFormatter.string(from: value as! Date) as NSString
				case (is NSNull):
					break;
				default:
					break;
				}
				return result + [pair.key: value]
			})
	}

	class func apply(installationData: Installation, to currentInstallation: InstallationDataService) {
		currentInstallation.isPrimaryDevice = installationData.isPrimaryDevice
		currentInstallation.isPushRegistrationEnabled = installationData.isPushRegistrationEnabled
		currentInstallation.customAttributes = installationData.customAttributes
		currentInstallation.applicationUserId = installationData.applicationUserId
	}
}
