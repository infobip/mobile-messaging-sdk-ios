//
//  MMRemoteAPIQueue.swift
//  MobileMessaging
//
//  Created by Andrey K. on 19/02/16.
//  
//
import Freddy

enum Result<ValueType> {
	case Success(ValueType)
	case Failure(NSError?)
	case Cancel

	var isFailure: Bool {
		return !isSuccess
	}
	
	var isSuccess: Bool {
		switch self {
		case .Success:
			return true
		case .Failure, .Cancel:
			return false
		}
	}
	
	var value: ValueType? {
		switch self {
		case .Success(let value):
			return value
		case .Failure, .Cancel:
			return nil
		}
	}
	
	var error: NSError? {
		switch self {
		case .Success, .Cancel:
			return nil
		case .Failure(let error):
			return error
		}
	}
}

class MMRemoteAPIQueue {
	private(set) var baseURL: String
	private(set) var applicationCode: String
	
	lazy var queue: MMRetryOperationQueue = {
		let q = MMRetryOperationQueue()
		q.maxConcurrentOperationCount = 1
		return q
	}()
	
	init(baseURL: String, applicationCode: String) {
        self.baseURL = baseURL
        self.applicationCode = applicationCode
    }
	
	func performRequest<R: MMHTTPRequestData>(request: R, completion: (Result<R.ResponseType>) -> Void) {
		let requestOperation = MMRetryableRequestOperation<R>(request: request, applicationCode: applicationCode, baseURL: baseURL) { responseResult in
			completion(responseResult)
			self.postErrorNotificationIfNeeded(responseResult.error)
		}
		queue.addOperation(requestOperation)
	}

	//MARK: Private
	private func postErrorNotificationIfNeeded(error: NSError?) {
		guard let error = error else {
			return
		}
		MMQueue.Main.queue.executeAsync {
			NSNotificationCenter.defaultCenter().postNotificationName(MMEventNotifications.kAPIError, object: self, userInfo: [MMEventNotifications.kAPIErrorUserInfoKey: error])
		}
	}
}