//
//  Message.swift
//
//  Created by Andrey K. on 15/09/16.
//
//

import Foundation
import CoreData

final class Message: NSManagedObject, Fetchable {

	override func MM_awakeFromCreation() {
		self.createdDate = MobileMessaging.date.now
	}
	
	var baseMessage: BaseMessage? {
		return BaseMessage.makeMessage(coreDataMessage: self)
	}
	
	var mtMessage: MTMessage? {
		return baseMessage as? MTMessage
	}
	
	var moMessage: MOMessage? {
		return baseMessage as? MOMessage
	}
}
