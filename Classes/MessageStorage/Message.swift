//
//  Message.swift
//
//  Created by Andrey K. on 15/09/16.
//
//

import Foundation
import CoreData

public final class Message: NSManagedObject, FetchableResult, UpdatableResult {

	static func makeMtMessage(from message: BaseMessage, context: NSManagedObjectContext) -> Message? {
		guard let mtMessage = message as? MTMessage else {
			return nil
		}
		let newMessage = Message.MM_createEntityInContext(context: context)
		newMessage.payload = mtMessage.originalPayload
		newMessage.messageId = mtMessage.messageId
		newMessage.direction = MessageDirection.MT.rawValue
		newMessage.deliveryMethod = mtMessage.deliveryMethod.rawValue
		newMessage.deliveryReportedDate = mtMessage.deliveryReportedDate
		newMessage.isDeliveryReportSent = mtMessage.deliveryReportedDate != nil
		newMessage.createdDate = Date(timeIntervalSince1970: mtMessage.sendDateTime)
		newMessage.seenDate = mtMessage.seenDate
		newMessage.seenStatusValue = mtMessage.seenStatus.rawValue
		return newMessage
	}
	
	static func makeMoMessage(from message: BaseMessage, context: NSManagedObjectContext) -> Message? {
		guard let moMessage = message as? MOMessage else {
			return nil
		}
		let newMessage = Message.MM_createEntityInContext(context: context)
		newMessage.payload = moMessage.dictRepresentation
		newMessage.messageId = moMessage.messageId
		newMessage.direction = MessageDirection.MO.rawValue
		newMessage.createdDate = moMessage.composedDate
		newMessage.sentStatusValue = moMessage.sentStatus.rawValue
		newMessage.seenStatusValue = MMSeenStatus.SeenSent.rawValue
		return newMessage
	}
	
	public var baseMessage: BaseMessage? {
		return BaseMessage.makeMessage(withMessageStorageMessageManagedObject: self)
	}
}
