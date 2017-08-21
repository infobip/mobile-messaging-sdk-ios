//
//  RemoteAPIQueue.swift
//  MobileMessaging
//
//  Created by Andrey K. on 19/02/16.
//  
//

enum Result<ValueType> {
	case Success(ValueType)
	case Failure(NSError?)
	case Cancel
	
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

class RemoteAPIQueue {
	private(set) var baseURL: String
	private(set) var applicationCode: String
	let mmContext: MobileMessaging
	
	lazy var queue: MMRetryOperationQueue = {
		return MMRetryOperationQueue.newSerialQueue
	}()
	
	init(mmContext: MobileMessaging, baseURL: String, applicationCode: String) {
		self.mmContext = mmContext
        self.baseURL = baseURL
        self.applicationCode = applicationCode
    }
	
	func perform<R: RequestData>(request: R, exclusively: Bool = false, completion: @escaping (Result<R.ResponseType>) -> Void) {
		let requestOperation = MMRetryableRequestOperation<R>(request: request, reachabilityManager: mmContext.reachabilityManager, applicationCode: applicationCode, baseURL: baseURL) { responseResult in
			completion(responseResult)
			self.postErrorNotificationIfNeeded(error: responseResult.error)
		}
		if exclusively {
			if queue.addOperationExclusively(requestOperation) == false {
				MMLogDebug("\(type(of: request)) cancelled due to non-exclusive condition.")
				completion(Result.Cancel)
			}
		} else {
			queue.addOperation(requestOperation)
		}
	}

	//MARK: Private
	private func postErrorNotificationIfNeeded(error: NSError?) {
		guard let error = error else {
			return
		}
		NotificationCenter.mm_postNotificationFromMainThread(name: MMNotificationAPIError, userInfo: [MMNotificationKeyAPIErrorUserInfo: error])
	}
}
