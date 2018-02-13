//
//  DynamicBaseUrlHTTPSessionManager.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 23/11/2017.
//

import Foundation

struct DynamicBaseUrlConsts {
	static let newBaseUrlHeader = "newbaseurl"
	static let storedDynamicBaseUrlKey = "com.mobile-messaging.dynamic-base-url"
}

class DynamicBaseUrlStorage: SingleKVStorage {
	var backingStorage: KVOperations = UserDefaults.standard
	typealias ValueType = URL
	var key: String {
		return DynamicBaseUrlConsts.storedDynamicBaseUrlKey
	}
	
	init(backingStorage: KVOperations = UserDefaults.standard) {
		self.backingStorage = backingStorage
	}
}

class DynamicBaseUrlHTTPSessionManager {
	let applicationCode: String
	var dynamicBaseUrl: URL?
	let originalBaseUrl: URL?
	let configuration: URLSessionConfiguration?
	let appGroupId: String?
	var storage: DynamicBaseUrlStorage
	
	init(applicationCode: String, baseURL url: URL?, sessionConfiguration configuration: URLSessionConfiguration?, appGroupId: String?) {
		self.applicationCode = applicationCode
		self.configuration = configuration
		self.originalBaseUrl = url
		self.appGroupId = appGroupId
		if let appGroupId = appGroupId, let sharedUserDefaults = UserDefaults(suiteName: appGroupId) {
			self.storage = DynamicBaseUrlStorage(backingStorage: sharedUserDefaults)
		} else {
			self.storage = DynamicBaseUrlStorage(backingStorage: UserDefaults.standard)
		}
		self.dynamicBaseUrl = getStoredDynamicBaseUrl() ?? url
	}
	
	private func storeDynamicBaseUrl(_ url: URL?) {
		if let url = url {
			storage.set(url)
		} else {
			storage.cleanUp()
		}
	}
	
	private func getStoredDynamicBaseUrl() -> URL? {
		return storage.get()
	}
	
	func sendRequest<R: RequestData>(_ request: R, completion: @escaping (Result<R.ResponseType>) -> Void) {
		let sessionManager = makeSessionManager(for: request)
		
		let successBlock = { (task: URLSessionDataTask, obj: Any?) -> Void in
			self.handleDynamicBaseUrl(response: task.response, error: nil)
			if let obj = obj as? R.ResponseType {
				completion(Result.Success(obj))
			} else {
				let error = NSError(domain: AFURLResponseSerializationErrorDomain, code: NSURLErrorCannotDecodeContentData, userInfo:[NSLocalizedFailureReasonErrorKey : "Request succeeded with no return value or return value wasn't a ResponseType value."])
				completion(Result.Failure(error))
			}
		}
		
		let failureBlock = { (task: URLSessionDataTask?, error: Error) -> Void in
			self.handleDynamicBaseUrl(response: task?.response, error: error as NSError?)
			completion(Result<R.ResponseType>.Failure(error as NSError?))
		}
		
		performRequest(request, sessionManager: sessionManager, successBlock: successBlock, failureBlock: failureBlock)
	}
	
	func makeSessionManager<R: RequestData>(for request: R) -> MM_AFHTTPSessionManager {
		let sessionManager = MM_AFHTTPSessionManager(baseURL: dynamicBaseUrl, sessionConfiguration: configuration)
		sessionManager.responseSerializer = ResponseSerializer<R.ResponseType>()
		sessionManager.requestSerializer = RequestSerializer(applicationCode: applicationCode, jsonBody: request.body, headers: request.headers)
		return sessionManager
	}
	
	func performRequest<R: RequestData>(_ request: R, sessionManager: MM_AFHTTPSessionManager, successBlock: @escaping (URLSessionDataTask, Any?) -> Void, failureBlock: @escaping (URLSessionDataTask?, Error) -> Void) {
		
		MMLogDebug("Sending request \(type(of: self))\nparameters: \(String(describing: request.parameters))\nbody: \(String(describing: request.body))\nto \(dynamicBaseUrl?.absoluteString ?? "empty-host" + request.path.rawValue)")
		
		switch request.method {
		case .POST:
			sessionManager.post(request.path.rawValue, parameters: request.parameters, progress: nil, success: successBlock, failure: failureBlock)
		case .PUT:
			sessionManager.put(request.path.rawValue, parameters: request.parameters, success: successBlock, failure: failureBlock)
		case .GET:
			sessionManager.get(request.path.rawValue, parameters: request.parameters, progress: nil, success: successBlock, failure: failureBlock)
		}
	}
	
	func handleDynamicBaseUrl(response: URLResponse?, error: NSError?) {
		if let error = error, error.mm_isCannotFindHost {
			storeDynamicBaseUrl(nil)
			dynamicBaseUrl = originalBaseUrl
		} else {
			if let httpResponse = response as? HTTPURLResponse, let newBaseUrlString = httpResponse.allHeaderFields[DynamicBaseUrlConsts.newBaseUrlHeader] as? String, let newDynamicBaseUrl = URL(string: newBaseUrlString) {
				storeDynamicBaseUrl(newDynamicBaseUrl)
				dynamicBaseUrl = newDynamicBaseUrl
			}
		}
	}
}
