//
//  Message.swift
//
//  Created by Andrey K. on 15/09/16.
//
//

import Foundation
import CoreData

public class Message: NSManagedObject {

	override func MM_awakeFromCreation() {
		self.createdDate = NSDate()
	}
	
	var baseMessage: BaseMessage? {
		return BaseMessage.makeMessage(self)
	}
	
	var mtMessage: MTMessage? {
		return baseMessage as? MTMessage
	}
	
	var moMessage: MOMessage? {
		return baseMessage as? MOMessage
	}
}
