//
//  MMRetryableOperation.swift
//  MobileMessaging
//

import Foundation

class MMRetryableOperation: Operation {

	typealias MMRetryableOperationCompletion = MMRetryableOperation -> Void
	private(set) var retryLimit = 0
	private(set) var currentError: NSError?
	private(set) var retryCounter = -1
	private var attemptObservers = [MMBlockObserver]()
	var finishCompletion: MMRetryableOperationCompletion
	
	func mapAttributesFrom(previous: MMRetryableOperation) {
		self.retryCounter = previous.retryCounter
	}
	
	required init(retryLimit: Int, completion: MMRetryableOperationCompletion) {
		self.retryLimit = retryLimit
		self.finishCompletion = completion
	}
	
	class func nextOperation(previousOperation: MMRetryableOperation) -> MMRetryableOperation? {
		let nextOp = previousOperation.dynamicType.init(retryLimit: previousOperation.retryLimit, completion: previousOperation.finishCompletion)
		nextOp.mapAttributesFrom(previousOperation)
		if !nextOp.shouldRetry(afterError: previousOperation.currentError) {
			return nil
		}
		return nextOp
	}
	
	func shouldRetry(afterError error: NSError?) -> Bool {
		var isErrorOkToRetry = false
		switch error {
		case .Some(let err) where err.mm_isRetryable:
			isErrorOkToRetry = true
		case .None:
			isErrorOkToRetry = false
		default:
			isErrorOkToRetry = false
		}
		return retryCounter < retryLimit && !cancelled && isErrorOkToRetry
	}
	
	func addObserver(observer: MMBlockObserver) {
		attemptObservers.append(observer)
	}
	
	override func execute() {
		retryCounter += 1
		for obs in attemptObservers {
			obs.attemptDidStart(self)
		}
	}
	
	override func finished(errors: [NSError]) {
		currentError = errors.first
		if !shouldRetry(afterError: currentError) {
			finishCompletion(self)
		}
		for obs in attemptObservers {
			obs.attemptDidFinish(self, error: currentError)
		}
		attemptObservers.removeAll()
	}
}