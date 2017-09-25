//
//  MMRetryableRequestOperation.swift
//  MobileMessaging
//

import Foundation
import MobileMessaging.Private

protocol ReachabilityManagerProtocol {
	func setReachabilityStatusChangeBlock(block: ((AFNetworkReachabilityStatus) -> Void)?)
	func currentlyReachable() -> Bool
	func startMonitoring()
	func stopMonitoring()
	var localizedNetworkReachabilityStatusString: String {get}
	var reachable: Bool {get}
}

class MMRetryableRequestOperation<RequestType: RequestData>: MMRetryableOperation {
	typealias ResponseTypeResult = Result<RequestType.ResponseType>
	private var operationQueue = MMQueue.Serial.New.RetryableRequest.queue
	private var operationResult: ResponseTypeResult = ResponseTypeResult.Failure(nil)
	private var request: RequestType?
	private var applicationCode: String?
	private var baseURL: String?
	private var reachabilityManager: ReachabilityManagerProtocol?
	
	override func copyAttributes(from operation: MMRetryableOperation) {
		super.copyAttributes(from: operation)
		if let operation = operation as? MMRetryableRequestOperation {
			self.request = operation.request
            self.applicationCode = operation.applicationCode
            self.baseURL = operation.baseURL
			self.reachabilityManager = operation.reachabilityManager
		}
	}
	
	required init(retryLimit: Int, completion: @escaping MMRetryableOperationCompletion) {
		super.init(retryLimit: retryLimit, completion: completion)
	}
	
	convenience init(request: RequestType, reachabilityManager: ReachabilityManagerProtocol?, applicationCode: String, baseURL: String, completion: @escaping (ResponseTypeResult) -> Void) {
		self.init(retryLimit: request.retryLimit) { finishedOperation in
			if let op = finishedOperation as? MMRetryableRequestOperation {
				completion(op.operationResult)
			}
		}
		self.request = request
		self.applicationCode = applicationCode
		self.baseURL = baseURL
		self.reachabilityManager = reachabilityManager
		self.name = "com.mobile-messaging.retryable-request-" + String(describing: type(of: request))
	}
	
	override func execute() {
		super.execute()
		sendRequest()
	}
	
	override func isErrorRetryable(_ error: NSError) -> Bool {
		return request?.mustRetryOnResponseError(error) ?? false
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
		request?.responseObject(applicationCode: applicationCode, baseURL: baseURL, completion: { result in
			self.operationQueue.executeSync { self.handleResult(result: result) }
		})
	}
	
	private func handleResult(result: ResponseTypeResult) {
		guard self.isCancelled == false else {
			finish(Result.Cancel)
			return
		}
		if let error = result.error {
			MMLogError("Failed request \(type(of: request)) on attempt #\(retryCounter) with error: \(error).")

			if let request = request, let rm = self.reachabilityManager, rm.currentlyReachable() == false, request.retryLimit > 0 {
				MMLogDebug("Network is not reachable now \(rm.localizedNetworkReachabilityStatusString).")
				MMLogDebug("Setting up a reachability listener...")
				rm.setReachabilityStatusChangeBlock {[weak self] status in
					MMLogDebug("Network Status Changed: \(rm.localizedNetworkReachabilityStatusString). Retrying request \(request.self)...")
					if rm.reachable {
						rm.stopMonitoring()
						self?.execute()
					}
				}
				rm.startMonitoring()
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
