//
//  MMRetryableRequestOperation.swift
//  MobileMessaging
//

import Foundation
import MobileMessaging.Private

protocol ReachabilityManagerProtocol {
	func setReachabilityStatusChangeBlock(timeout: DispatchTimeInterval, timeoutBlock: @escaping () -> Void, block: @escaping ((AFNetworkReachabilityStatus) -> Void))
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
	
	// required attributes, must be copied
	private var request: RequestType!
	private var reachabilityManager: ReachabilityManagerProtocol!
	private var sessionManager: DynamicBaseUrlHTTPSessionManager!
	
	deinit {
		reachabilityManager.stopMonitoring()
	}
	
	override func copy() -> Any {
		let acopy = super.copy()
		if let acopy = acopy as? MMRetryableRequestOperation {
			acopy.request = self.request
			acopy.sessionManager = self.sessionManager
			acopy.reachabilityManager = self.reachabilityManager
		}
		return acopy
	}
	
	required init(retryLimit: Int, completion: @escaping MMRetryableOperationCompletion) {
		super.init(retryLimit: retryLimit, completion: completion)
	}
	
	convenience init(request: RequestType, reachabilityManager: ReachabilityManagerProtocol, sessionManager: DynamicBaseUrlHTTPSessionManager, completion: @escaping (ResponseTypeResult) -> Void) {
		self.init(retryLimit: request.retryLimit) { finishedOperation in
			if let op = finishedOperation as? MMRetryableRequestOperation {
				completion(op.operationResult)
			}
		}
		self.sessionManager = sessionManager
		self.request = request
		self.reachabilityManager = reachabilityManager
		self.name = "com.mobile-messaging.retryable-request-" + String(describing: type(of: request))
	}
	
	override func execute() {
		super.execute()
		sendRequest()
	}
	
	override func isErrorRetryable(_ error: NSError) -> Bool {
		return request.mustRetryOnResponseError(error)
	}
	
	private func sendRequest() {
		guard self.isCancelled == false else {
			finish(Result.Cancel)
			return
		}
		sessionManager.sendRequest(request, completion: { result in
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
			if reachabilityManager.currentlyReachable() == false && request.retryLimit > 0 {
				MMLogDebug("Network is not reachable now \(reachabilityManager.localizedNetworkReachabilityStatusString).")
				MMLogDebug("Setting up a reachability listener...")
				reachabilityManager.startMonitoring()
				reachabilityManager.setReachabilityStatusChangeBlock(
					timeout: SDKSettings.reachabilityMonitoringTimeout,
					timeoutBlock: { [weak self] in
						self?.reachabilityManager.stopMonitoring()
						self?.finish(Result.Failure(error))
					},
					block: { [weak self] status in
						if let rm = self?.reachabilityManager {
							MMLogDebug("Network Status Changed: \(rm.localizedNetworkReachabilityStatusString).")
							if rm.reachable {
								MMLogDebug("It's reachable now, retrying request \(String(describing: self?.request.self))")
								rm.stopMonitoring()
								self?.execute()
							}
						}
					})
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
