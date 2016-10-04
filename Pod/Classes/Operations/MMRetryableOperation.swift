//
//  MMRetryableOperation.swift
//  MobileMessaging
//

import Foundation

class MMRetryableOperation: Operation {

	private var _retryCounter = -1
	private let counterLock = NSLock()
	private(set) var retryCounter: Int {
		set {
			counterLock.withCriticalScope {
				self._retryCounter = newValue
			}
		}
		get {
			return counterLock.withCriticalScope {
				 self._retryCounter
			}
		}
	}
	
	typealias MMRetryableOperationCompletion = (MMRetryableOperation) -> Void
	private(set) var retryLimit = 0
	private(set) var currentError: NSError?
	
	private var attemptObservers = [MMBlockObserver]()
	var finishCompletion: MMRetryableOperationCompletion
	
	func copyAttributes(from operation: MMRetryableOperation) {
		retryCounter = operation.retryCounter
	}
	
	required init(retryLimit: Int, completion: @escaping MMRetryableOperationCompletion) {
		self.retryLimit = retryLimit
		self.finishCompletion = completion
	}
	
	class func makeSuccessor(withPredecessor predecessorOperation: MMRetryableOperation) -> MMRetryableOperation? {
		let nextOp = type(of: predecessorOperation).init(retryLimit: predecessorOperation.retryLimit, completion: predecessorOperation.finishCompletion)
		nextOp.copyAttributes(from: predecessorOperation)
		if !nextOp.shouldRetry(afterError: predecessorOperation.currentError) {
			return nil
		}
		return nextOp
	}
	
	private func shouldRetry(afterError error: NSError?) -> Bool {
		var isErrorOkToRetry = false
		switch error {
		case .some(let err) where err.mm_isRetryable:
			isErrorOkToRetry = true
		case .none:
			isErrorOkToRetry = false
		default:
			isErrorOkToRetry = false
		}

		return retryCounter < retryLimit && !isCancelled && isErrorOkToRetry
	}
	
	func addObserver(observer: MMBlockObserver) {
		attemptObservers.append(observer)
	}
	
	override func execute() {
		retryCounter += 1
		for obs in attemptObservers {
			obs.attemptDidStart(operation: self)
		}
	}
	
	override func finished(_ errors: [NSError]) {
		currentError = errors.first
		if !shouldRetry(afterError: currentError) {
			finishCompletion(self)
		}
		for obs in attemptObservers {
			obs.attemptDidFinish(operation: self, error: currentError)
		}
		attemptObservers.removeAll()
	}
}
