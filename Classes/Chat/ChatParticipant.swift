//
//  ChatParticipant.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 20/10/2017.
//

import Foundation

struct CustomUserDataChatKeys {
	static let customData = "chatCustomData"
}

public func ==(l: ChatParticipant, r: ChatParticipant) -> Bool {
	return l.id == r.id
}

func jsonToCustomUserDataValue(json: JSON?) -> AttributeType? {
	guard let json = json, let jsonStr = json.rawString() else {
		return nil
	}
	return jsonStr as NSString
}

func customUserDataValueToJson(value: AttributeType?) -> JSON? {
	guard let jsonString = value as? String else {
		return nil
	}
	return JSON.parse(jsonString)
}

public class ChatParticipant: NSObject {
	// keep attributes in sync with those used in `applyChatParticipantAttributes()`
	public var id: String?
	public var firstName: String?
	public var lastName: String?
	public var middleName: String?
	public var email: String?
	public var gsm: String?
	public var username: String? {
		let ret = "\(firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") \(lastName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")".trimmingCharacters(in: .whitespacesAndNewlines)
		return ret.isEmpty ? nil : ret
	}
	var customData: JSON?
	
	public static var current: ChatParticipant? {
		guard let user = MobileMessaging.getUser(), let installation = MobileMessaging.getInstallation() else {
			return nil
		}
		return ChatParticipant.current(with: user, installation: installation)
	}
	
	static func current(with user: User, installation: Installation) -> ChatParticipant? {
		let participantId = user.externalUserId ?? installation.pushRegistrationId
		return ChatParticipant(id: participantId,
							   firstName: user.firstName,
							   lastName: user.lastName,
							   middleName: user.middleName,
							   email: user.emails?.first,//(where: { return $0.preferred })?.address,
							   gsm: user.phones?.first,//(where: { return $0.preferred })?.number,
							   customData: customUserDataValueToJson(value: user.customAttributes?[CustomUserDataChatKeys.customData]))
	}
	
	init(id: String?, firstName: String?, lastName: String?, middleName: String?, email: String?, gsm: String?, customData: JSON? = nil) {
		self.id = id
		self.firstName = firstName
		self.lastName = lastName
		self.middleName = middleName
		self.email = email
		self.gsm = gsm
		self.customData = customData
	}
	
	convenience init?(dictRepresentation dict: DictionaryRepresentation) {
		let customDataJson: JSON?
		if let jsonString = dict[CustomPayloadChatKeys.Sender.customData] as? String {
			customDataJson = JSON.parse(jsonString)
		} else {
			customDataJson = nil
		}
		
		self.init(id: dict[CustomPayloadChatKeys.Sender.id] as? String,
				  firstName: dict[CustomPayloadChatKeys.Sender.firstName] as? String,
				  lastName: dict[CustomPayloadChatKeys.Sender.lastName] as? String,
				  middleName: dict[CustomPayloadChatKeys.Sender.middleName] as? String,
				  email: dict[CustomPayloadChatKeys.Sender.email] as? String,
				  gsm: dict[CustomPayloadChatKeys.Sender.gsm] as? String,
				  customData: customDataJson)
	}
	
	var dictionaryRepresentation: DictionaryRepresentation {
		return [CustomPayloadChatKeys.Sender.id: id as Any,
				CustomPayloadChatKeys.Sender.firstName: firstName as Any,
				CustomPayloadChatKeys.Sender.lastName: lastName as Any,
				CustomPayloadChatKeys.Sender.middleName: middleName as Any,
				CustomPayloadChatKeys.Sender.email: email as Any,
				CustomPayloadChatKeys.Sender.gsm: gsm as Any,
				CustomPayloadChatKeys.Sender.customData: customData?.rawString() as Any]
	}
}
