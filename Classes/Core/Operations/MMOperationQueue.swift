//
//  MMOperationQueue.swift
//
//  Created by Andrey Kadochnikov on 16/02/2017.
//
//

import UIKit

class MMOperationQueue: OperationQueue {
	func addOperationExclusively(_ operation: Foundation.Operation) -> Bool {
		guard operations.contains(where: { type(of: $0) == type(of: operation) }) == false else
		{
			MMLogDebug("\(type(of: operation)) was not queued because a queue is already taken with the same kind of operation.")
			return false
		}
		addOperation(operation)
		return true
	}
	
	override init() {
		super.init()
		self.name = self.operationName
	}
	
	var operationName: String {
		return "com.mobile-messaging.default-queue"
	}
	
	class var newSerialQueue: MMOperationQueue {
		let newQ = MMOperationQueue()
		newQ.maxConcurrentOperationCount = 1
		newQ.qualityOfService = .default
		return newQ
	}
	
	class var userInitiatedQueue: MMOperationQueue {
		let newQ = MMOperationQueue()
		newQ.qualityOfService = .userInitiated
		newQ.maxConcurrentOperationCount = 1
		return newQ
	}
}
