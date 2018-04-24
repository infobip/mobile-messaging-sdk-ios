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

extension MMUser {
	func applyChatParticipantAttributes(participantInfo: ChatParticipant) {
		guard let mmuser = MobileMessaging.sharedInstance?.currentUser else {
			return
		}
        if let externalId = participantInfo.id {
            mmuser.externalId = externalId
        }
		mmuser.set(predefinedData: participantInfo.firstName, forKey: .FirstName)
		mmuser.set(predefinedData: participantInfo.lastName, forKey: .LastName)
		mmuser.set(predefinedData: participantInfo.middleName, forKey: .MiddleName)
		mmuser.set(predefinedData: participantInfo.email, forKey: .Email)
		mmuser.set(predefinedData: participantInfo.gsm, forKey: .MSISDN)
		mmuser.set(customData: jsonToCustomUserDataValue(json: participantInfo.customData), forKey: CustomUserDataChatKeys.customData)
	}
}

func jsonToCustomUserDataValue(json: JSON?) -> CustomUserDataValue? {
	guard let json = json, let jsonStr = json.rawString() else {
		return nil
	}
	return CustomUserDataValue(string:  jsonStr)
}

func customUserDataValueToJson(value: CustomUserDataValue?) -> JSON? {
	guard let jsonString = value?.string else {
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
	var customData: JSON? //TODO: make public (but don't expose JSON - as comutable dict variable)
	
    public static var current: ChatParticipant? {
		guard let user = MobileMessaging.sharedInstance?.currentUser else {
			return nil
		}
		return ChatParticipant.current(with: user)
	}
	
	static func current(with user: MMUser) -> ChatParticipant? {
		let participantId = user.externalId ?? user.pushRegistrationId
        return ChatParticipant(id: participantId,
                               firstName: user.predefinedData(forKey: .FirstName),
                               lastName: user.predefinedData(forKey: .LastName),
                               middleName: user.predefinedData(forKey: .MiddleName),
                               email: user.predefinedData(forKey: .Email),
                               gsm: user.predefinedData(forKey: .MSISDN),
                               customData: customUserDataValueToJson(value: user.customData?[CustomUserDataChatKeys.customData]))
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
