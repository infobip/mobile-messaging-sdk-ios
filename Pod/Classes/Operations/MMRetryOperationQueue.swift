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
    private let startHandler: (MMRetryableOperation -> Void)?
    private let finishHandler: ((MMRetryableOperation, NSError?) -> Void)?
	
	init(startHandler: (MMRetryableOperation -> Void)? = nil, finishHandler: ((MMRetryableOperation, NSError?) -> Void)? = nil) {
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
	
	override func addOperation(operation: NSOperation) {
		if let op = operation as? MMRetryableOperation {
			let obs = MMBlockObserver(startHandler: nil,
			                          finishHandler: { [weak self] (operation, error) -> Void in
										if let strongSelf = self {
											strongSelf.scheduleRetry(operation)
										}
				}
			)
			op.addObserver(obs)
		}
		super.addOperation(operation)
    }
	
	private func scheduleRetry(operation: MMRetryableOperation) {
		if let newOperation = operation.dynamicType.nextOperation(operation) {
			let retryNumber = newOperation.retryCounter + 1
			let delay = pow(Double(retryNumber), 2)
			MMLogInfo("Scheduled retry attempt #\(retryNumber) for request \(newOperation.dynamicType) in \(delay) seconds.")
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC))), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
				self.addOperation(newOperation)
			})
		}
	}
	
	override func addOperations(ops: [NSOperation], waitUntilFinished wait: Bool) {
		for op in ops {
			addOperation(op)
			if wait {
				op.waitUntilFinished()
			}
		}
	}
}