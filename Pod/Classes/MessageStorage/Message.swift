//
//  Message.swift
//
//  Created by Andrey K. on 15/09/16.
//
//

import Foundation
import CoreData

final class Message: NSManagedObject, Fetchable {

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
		return newMessage
	}
	
	override func MM_awakeFromCreation() {
		self.createdDate = MobileMessaging.date.now
	}
	
	var baseMessage: BaseMessage? {
		return BaseMessage.makeMessage(withMessageStorageMessageManagedObject: self)
	}
	
	var mtMessage: MTMessage? {
		return baseMessage as? MTMessage
	}
	
	var moMessage: MOMessage? {
		return baseMessage as? MOMessage
	}
}
