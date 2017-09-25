//
//  RetryableNetworkingOperation.swift
//
//  Created by Andrey K. on 08/12/2016.
//
//

import Foundation

class RetryableNetworkingOperation: MMRetryableOperation {
	
	private var operationQueue = MMQueue.Serial.New.RetryableRequest.queue
	var reachabilityManager: MMNetworkReachabilityManager
	
	required init(retryLimit: Int, completion: @escaping MMRetryableOperationCompletion) {
		self.reachabilityManager = MMNetworkReachabilityManager.sharedInstance
		super.init(retryLimit: retryLimit, completion: completion)
		super.name = "com.mobile-messaging.operation.retryable-networking." + String(describing: type(of: self))
	}
	
	override func execute() {
		if reachabilityManager.currentlyReachable() == false {
			MMLogDebug("Network is not reachable now \(reachabilityManager.localizedNetworkReachabilityStatusString). Setting up a reachability listener...")
			reachabilityManager.setReachabilityStatusChangeBlock {[weak self] status in
				MMLogDebug("Network Status Changed: \(String(describing: self?.reachabilityManager.localizedNetworkReachabilityStatusString)). Retrying...")
				if self?.reachabilityManager.reachable ?? false {
					self?.reachabilityManager.stopMonitoring()
					self?.executeAttempt()
				}
			}
			reachabilityManager.startMonitoring()
		} else {
			self.executeAttempt()
		}
	}
	
	// override me!
	func executeAttempt() {
		super.execute()
	}
}

var reachabilityError: NSError {
	return NSError(domain: "com.mobile-messaging", code: 991, userInfo: nil)
}
