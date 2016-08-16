//
//  MMRetryableRequestOperation.swift
//  MobileMessaging
//

import Foundation
import MMAFNetworking

class MMRetryableRequestOperation<RequestType: MMHTTPRequestData>: MMRetryableOperation {
	typealias ResponseTypeResult = Result<RequestType.ResponseType>
	private var operationQueue = MMQueue.Serial.New.RetryableRequest.queue
	private var operationResult: ResponseTypeResult = ResponseTypeResult.Failure(nil)
	private var request: RequestType?
	private var applicationCode: String?
	private var baseURL: String?
	var reachabilityManager: MMNetworkReachabilityManager
	
	override func mapAttributesFrom(previous: MMRetryableOperation) {
		super.mapAttributesFrom(previous)
		if let previous = previous as? MMRetryableRequestOperation {
			self.request = previous.request
            self.applicationCode = previous.applicationCode;
            self.baseURL = previous.baseURL;
		}
	}
	
	required init(retryLimit: Int, completion: MMRetryableOperationCompletion) {
		self.reachabilityManager = MMNetworkReachabilityManager.sharedInstance
		super.init(retryLimit: retryLimit, completion: completion)
	}
	
	convenience init(request: RequestType, applicationCode: String, baseURL: String, completion: ResponseTypeResult -> Void) {
		self.init(retryLimit: request.retryLimit) { finishedOperation in
			if let op = finishedOperation as? MMRetryableRequestOperation {
				completion(op.operationResult)
			}
		}
		self.request = request
		self.applicationCode = applicationCode
		self.baseURL = baseURL
		self.name = "com.mobile-messaging.retryable-request-" + String(request.dynamicType)
	}
	
	override func execute() {
		super.execute()
		sendRequest()
	}
	
	private func sendRequest() {
		guard self.cancelled == false else {
			finish(Result.Cancel)
			return
		}
		guard let applicationCode = applicationCode, let baseURL = baseURL else {
			finish(Result.Failure(NSError(type: MMInternalErrorType.UnknownError)))
			return
		}
		request?.responseObject(applicationCode, baseURL: baseURL) { result in
			self.operationQueue.executeSync { self.handleResult(result) }
		}
	}
	
	private func handleResult(result: ResponseTypeResult) {
		guard self.cancelled == false else {
			finish(Result.Cancel)
			return
		}
		if let error = result.error {
			MMLogError("Failed request \(request.dynamicType) on attempt #\(retryCounter) with error: \(error).")
			if reachabilityManager.currentlyReachable() == false {
				MMLogInfo("Network is not reachable now \(reachabilityManager.localizedNetworkReachabilityStatusString). Setting up a reachability listener...")
				reachabilityManager.setReachabilityStatusChangeBlock {[weak self] status in
					MMLogInfo("Network Status Changed: \(self?.reachabilityManager.localizedNetworkReachabilityStatusString). Retrying request \(self?.request.self)...")
					if self?.reachabilityManager.reachable ?? false {
						self?.reachabilityManager.stopMonitoring()
						self?.execute()
					}
				}
				reachabilityManager.startMonitoring()
			} else {
				finish(Result.Failure(error))
			}
		} else {
			MMLogInfo("Request \(request.dynamicType) succeeded.")
			finish(result)
		}
	}
	
	private func finish(result: ResponseTypeResult) {
		self.operationResult = result
		super.finishWithError(result.error)
	}
}