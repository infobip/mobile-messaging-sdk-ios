//
//  ChatMessage.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 18/10/2017.
//

import Foundation

struct CustomPayloadChatKeys {
	static let chatId = "chatId"
	struct Sender {
		static let id = "sender"
		static let firstName = "senderFirstName"
		static let lastName = "senderLastName"
		static let middleName = "senderMiddleName"
		static let email = "senderEmail"
		static let gsm = "senderGsm"
		static let customData = "senderData"
	}
}

public protocol ChatMessageProtocol: MTMessageProtocol, MOMessageProtocol {
	var body: String {get}
	var chatId: String? {get}
	var id: String {get}
	var receivedAt: Date? {get}
	var author: ChatParticipant? {get}
}

public class ChatMessage: NSObject, ChatMessageProtocol {
	public override var hash: Int {
		return id.hashValue
	}
	
	public func isEqual(object: Any?) -> Bool {
		guard let otherMessage = object as? ChatMessage else {
			return false
		}
		return id == otherMessage.id
	}
	
	public var body: String {
		return mt?.text ?? mo?.text ?? ""
	}
	
	public var id: String
	
	public let chatId: String?
	
	public let receivedAt: Date?
	
	public let author: ChatParticipant?
	
	public var appliedAction: NotificationAction? {
		get {
			return mt?.appliedAction
		}
		set {
			mt?.appliedAction = newValue
		}
	}
	
	public var aps: PushPayloadAPS {
		return mt?.aps ?? PushPayloadAPS.undefined
	}
	
	public var originalPayload: APNSPayload {
		return mt?.originalPayload ?? mo?.originalPayload ?? [:]
	}
	
	public var deliveryMethod: MessageDeliveryMethod {
		return mt?.deliveryMethod ?? mo?.deliveryMethod ?? .undefined
	}
	
	public var isSilent: Bool {
		return mt?.isSilent ?? false
	}
	
	public var title: String? {
		return mt?.title
	}
	
	public var title_loc_key: String? {
		return mt?.title_loc_key
	}
	
	public var title_loc_args: [String]? {
		return mt?.title_loc_args
	}
	
	public var loc_key: String? {
		return mt?.loc_key
	}
	
	public var loc_args: [String]? {
		return mt?.loc_args
	}
	
	public var sound: String? {
		return mt?.sound
	}
	
	public var category: String? {
		return mt?.category
	}
	
	public var badge: Int? {
		return mt?.badge
	}
	
	public var contentUrl: String? {
		return mt?.contentUrl
	}
	
	public var sendDateTime: TimeInterval {
		return mt?.sendDateTime ?? 0
	}
	
	public var seenStatus: MMSeenStatus {
		return mt?.seenStatus ?? .NotSeen
	}
	
	public var seenDate: Date? {
		return mt?.seenDate
	}
	
	public var isDeliveryReportSent: Bool {
		return mt?.isDeliveryReportSent ?? false
	}
	
	public var deliveryReportedDate: Date? {
		return mt?.deliveryReportedDate
	}
	
	public var internalData: StringKeyPayload? {
		return mt?.internalData
	}
	
	public var silentData: StringKeyPayload? {
		return mt?.silentData
	}
	
	public var isGeoSignalingMessage: Bool {
		return mt?.isGeoSignalingMessage ?? false
	}
	
	public var destination: String? {
		return mo?.destination
	}
	
	public var sentStatus: MOMessageSentStatus {
		return mo?.sentStatus ?? .Undefined
	}
	
	public var composedDate: Date {
		return mo?.composedDate ?? MobileMessaging.date.now
	}
	
	public var bulkId: String? {
		return mo?.bulkId
	}
	
	public var initialMessageId: String? {
		return mo?.initialMessageId
	}
	
	var mo: MOMessage?
	var mt: MTMessage?
	
	public var isYours: Bool {
		guard let pushRegId = MobileMessaging.installation?.pushRegistrationId else {
			return false
		}
		switch author {
		case .some(let a):
			return pushRegId == a.id
		case .none:
			return false
		}
	}
	
	// from users initiative
	convenience init(chatId: String?, text: String, customPayload: [String: CustomPayloadSupportedTypes]?, composedData: Date, author: ChatParticipant) {
		var chatMessageRequiredCustomData: [String: CustomPayloadSupportedTypes] =
			[
				Consts.CustomPayloadKeys.isChat: true as NSNumber,
				CustomPayloadChatKeys.chatId: chatId as NSString? ?? NSNull(),
				CustomPayloadChatKeys.Sender.id: author.id as NSString? ?? NSNull(),
				CustomPayloadChatKeys.Sender.firstName: author.firstName as NSString? ?? NSNull(),
				CustomPayloadChatKeys.Sender.lastName: author.lastName as NSString? ?? NSNull(),
				CustomPayloadChatKeys.Sender.middleName: author.middleName as NSString? ?? NSNull(),
				CustomPayloadChatKeys.Sender.email: author.email as NSString? ?? NSNull(),
				CustomPayloadChatKeys.Sender.gsm: author.gsm as NSString? ?? NSNull(),
				CustomPayloadChatKeys.Sender.customData: author.customData?.rawString() as NSString? ?? NSNull()
		]
		if let customPayload = customPayload {
			chatMessageRequiredCustomData.merge(customPayload, uniquingKeysWith: { (curr, new) -> CustomPayloadSupportedTypes in
				return curr
			})
		}
		
		let momessage = MOMessage(destination: nil, text: text, customPayload: chatMessageRequiredCustomData, composedDate: composedData)
		self.init(moMessage: momessage)!
	}
	
	// from mo sending, mo response
	init?(moMessage mo: MOMessage) {
		guard let customPayload = mo.customPayload, let author = ChatParticipant(dictRepresentation: customPayload), customPayload.isChatMessage else {
			return nil
		}
		
		self.id = mo.messageId
		self.mo = mo
		self.receivedAt = nil
		self.chatId = mo.customPayload?[CustomPayloadChatKeys.chatId] as? String
		self.author = author
	}
	
	init?(mtMessage mt: MTMessage) {
		guard let customPayload = mt.customPayload, let author = ChatParticipant(dictRepresentation: customPayload), customPayload.isChatMessage else {
			return nil
		}
		
		self.id = mt.messageId
		self.mt = mt
		self.receivedAt = MobileMessaging.date.now
		self.chatId = customPayload[CustomPayloadChatKeys.chatId] as? String
		self.author = author
	}
	
	convenience init?(message: Message) {
		guard let direction = MessageDirection(rawValue: message.direction) else {
			return nil
		}
		switch direction {
		case .MT:
			if let mt = MTMessage(messageStorageMessageManagedObject: message) {
				self.init(mtMessage: mt)
			} else {
				return nil
			}
		case .MO:
			if let mo = MOMessage(messageStorageMessageManagedObject: message) {
				self.init(moMessage: mo)
			} else {
				return nil
			}
		}
	}
}

