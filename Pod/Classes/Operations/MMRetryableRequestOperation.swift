//
//  MMRetryableRequestOperation.swift
//  MobileMessaging
//

import Foundation

class MMRetryableRequestOperation<RequestType: MMHTTPRequestData>: MMRetryableOperation {
	typealias ResponseTypeResult = Result<RequestType.ResponseType>
	private var operationQueue = MMQueue.Serial.New.RetryableRequest.queue
	private var operationResult: ResponseTypeResult = ResponseTypeResult.Failure(nil)
	private var request: RequestType?
	private var applicationCode: String?
	private var baseURL: String?
	var reachabilityManager: MMNetworkReachabilityManager
	
	override func mapAttributesFrom(previous: MMRetryableOperation) {
		super.mapAttributesFrom(previous: previous)
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
	
	convenience init(request: RequestType, applicationCode: String, baseURL: String, completion: @escaping (ResponseTypeResult) -> Void) {
		self.init(retryLimit: request.retryLimit) { finishedOperation in
			if let op = finishedOperation as? MMRetryableRequestOperation {
				completion(op.operationResult)
			}
		}
		self.request = request
		self.applicationCode = applicationCode
		self.baseURL = baseURL
		self.name = "com.mobile-messaging.retryable-request-" + String(describing: type(of: request))
	}
	
	override func execute() {
		super.execute()
		sendRequest()
	}
	
	private func sendRequest() {
		guard self.isCancelled == false else {
			finish(Result.Cancel)
			return
		}
		guard let applicationCode = applicationCode, let baseURL = baseURL else {
			finish(Result.Failure(NSError(type: MMInternalErrorType.UnknownError)))
			return
		}
		request?.responseObject(applicationCode: applicationCode, baseURL: baseURL) { result in
			self.operationQueue.executeSync { self.handleResult(result: result) }
		}
	}
	
	private func handleResult(result: ResponseTypeResult) {
		guard self.isCancelled == false else {
			finish(Result.Cancel)
			return
		}
		if let error = result.error {
			MMLogError("Failed request \(type(of: request)) on attempt #\(retryCounter) with error: \(error).")
			if reachabilityManager.currentlyReachable() == false {
				MMLogDebug("Network is not reachable now \(reachabilityManager.localizedNetworkReachabilityStatusString). Setting up a reachability listener...")
				reachabilityManager.setReachabilityStatusChangeBlock {[weak self] status in
					MMLogDebug("Network Status Changed: \(self?.reachabilityManager.localizedNetworkReachabilityStatusString). Retrying request \(self?.request.self)...")
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
			MMLogDebug("Request \(type(of: request)) succeeded.")
			finish(result)
		}
	}
	
	private func finish(_ result: ResponseTypeResult) {
		self.operationResult = result
		super.finishWithError(result.error)
	}
}
