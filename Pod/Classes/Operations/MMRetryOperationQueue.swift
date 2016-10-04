//
//  MMRetryOperationQueue.swift
//  MobileMessaging
//

import Foundation

protocol MMOperationObserver {
    func attemptDidStart(operation: MMRetryableOperation)
	func attemptDidFinish(operation: MMRetryableOperation, error: NSError?)
}

struct MMBlockObserver: MMOperationObserver {
    private let startHandler: ((MMRetryableOperation) -> Void)?
    private let finishHandler: ((MMRetryableOperation, NSError?) -> Void)?
	
	init(startHandler: ((MMRetryableOperation) -> Void)? = nil, finishHandler: ((MMRetryableOperation, NSError?) -> Void)? = nil) {
		self.startHandler = startHandler
		self.finishHandler = finishHandler
	}
	
    func attemptDidStart(operation: MMRetryableOperation) {
        startHandler?(operation)
    }
    
	func attemptDidFinish(operation: MMRetryableOperation, error: NSError?) {
		finishHandler?(operation, error)
    }
}

class MMRetryOperationQueue: OperationQueue {
	override init() {
		super.init()
		self.name = "com.mobile-messaging.retryable-operation-queue"
	}
	
	override func addOperation(_ operation: Foundation.Operation) {
		if let op = operation as? MMRetryableOperation {
			let obs = MMBlockObserver(startHandler: nil,
			                          finishHandler:
				{ [weak self] (operation, error) -> Void in
					if let strongSelf = self {
						strongSelf.scheduleRetry(for: operation)
					}
				}
			)
			op.addObserver(observer: obs)
		}
		super.addOperation(operation)
	}
	
	private func scheduleRetry(for operation: MMRetryableOperation) {
		if let newOperation = type(of: operation).makeSuccessor(withPredecessor: operation) {
			let retryNumber = newOperation.retryCounter + 1
			let delay = pow(Double(retryNumber), 2)
			MMLogDebug("Scheduled retry attempt #\(retryNumber) for request \(type(of: newOperation)) in \(delay) seconds.")
			DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: {
				self.addOperation(newOperation)
			})
		}
	}
	
	override func addOperations(operations: [Foundation.Operation], waitUntilFinished wait: Bool) {
		for op in operations {
			addOperation(op)
			if wait {
				op.waitUntilFinished()
			}
		}
	}
}
