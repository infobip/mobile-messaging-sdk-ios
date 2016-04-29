//
//  MMSessionManager.swift
//  Pods
//
//  Created by Andrey K. on 14/04/16.
//
//

import MMAFNetworking

class MMHTTPSessionManager : MM_AFHTTPSessionManager {
	
	class func sendRequest<R: MMHTTPRequestData>(request: R, baseURL: String, applicationCode: String, completion: Result<R.ResponseType> -> Void) -> Void {
		let manager = MMHTTPSessionManager(baseURL: NSURL(string: baseURL), sessionConfiguration: NSURLSessionConfiguration.defaultSessionConfiguration())
		manager.requestSerializer = MMHTTPRequestSerializer(applicationCode: applicationCode, jsonBody: request.body)
		manager.responseSerializer = MMResponseSerializer<R.ResponseType>()
		
		var params: [String: AnyObject] = [MMAPIKeys.kPlatformType:request.platformType]
		params += request.parameters
		MMLogInfo("Sending request \(request.dynamicType) w/parameters: \(params) to \(baseURL + request.path.rawValue)")
		
		let successBlock = { (task: NSURLSessionDataTask, obj: AnyObject?) -> Void in
			if let obj = obj as? R.ResponseType {
				completion(Result.Success(obj))
			} else {
				let error = NSError(domain: AFURLResponseSerializationErrorDomain, code: NSURLErrorCannotDecodeContentData, userInfo:nil)
				completion(Result.Failure(error))
			}
		}
		
		let failureBlock = { (task: NSURLSessionDataTask?, error: NSError) -> Void in
			completion(Result<R.ResponseType>.Failure(error))
		}
		
		let urlString = manager.baseURL!.absoluteString + request.path.rawValue
		switch request.method {
		case .POST:
			manager.POST(urlString, parameters: params, progress: nil, success: successBlock, failure: failureBlock)
		case .PUT:
			manager.PUT(urlString, parameters: params, success: successBlock, failure: failureBlock)
		case .GET:
			manager.GET(urlString, parameters: params, progress: nil, success: successBlock, failure: failureBlock)
		}
	}
}