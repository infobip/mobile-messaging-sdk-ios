//
//  DynamicBaseUrlHTTPSessionManager.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 23/11/2017.
//

import Foundation

class SanitizedJSONSerialization: JSONSerialization {
	override class func data(withJSONObject obj: Any, options opt: JSONSerialization.WritingOptions = []) throws -> Data {

		let data = try super.data(withJSONObject: obj, options: opt)
		let jsonString = String(data: data, encoding: String.Encoding.utf8)
		let sanitizedString = jsonString?.replacingOccurrences(of: "\\/", with: "/")
		return sanitizedString?.data(using: String.Encoding.utf8) ?? Data()
	}
}

struct JSONRequestEncoding<R: RequestData>: ParameterEncoding {
	let request: R
	func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
		var urlRequest = try urlRequest.asURLRequest()
		if let jsonBody = request.body {
			urlRequest.httpBody = try SanitizedJSONSerialization.data(withJSONObject: jsonBody, options: [])
		}
		urlRequest = try URLEncoding.queryString.encode(urlRequest, with: parameters)
		return urlRequest
	}
}


class DynamicBaseUrlStorage: SingleKVStorage {
	var backingStorage: KVOperations = UserDefaults.standard
	typealias ValueType = URL
	var key: String {
		return Consts.DynamicBaseUrlConsts.storedDynamicBaseUrlKey
	}
	
	init(backingStorage: KVOperations = UserDefaults.standard) {
		self.backingStorage = backingStorage
	}
}

class DynamicBaseUrlHTTPSessionManager {
	var dynamicBaseUrl: URL?
	var originalBaseUrl: URL
	let configuration: URLSessionConfiguration
	let alamofireSessionManager: SessionManager

	let appGroupId: String?
	var storage: DynamicBaseUrlStorage

	init(baseURL url: URL, sessionConfiguration configuration: URLSessionConfiguration?, appGroupId: String?) {
		self.configuration = configuration ?? URLSessionConfiguration.default
		self.configuration.timeoutIntervalForResource = 20
		self.configuration.timeoutIntervalForRequest = 20
		self.alamofireSessionManager = SessionManager(configuration: self.configuration)
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

	func url<R: RequestData>(_ r: R) -> String {
		return (dynamicBaseUrl ?? originalBaseUrl).absoluteString + r.resolvedPath
	}

	func getDataResponse<R: RequestData>(_ r: R, completion: @escaping (HTTPURLResponse?, JSON?, NSError?) -> Void) {
		let request = alamofireSessionManager.request(url(r), method: r.method, parameters: r.parameters, encoding: JSONRequestEncoding(request: r), headers: r.headers)
		MMLogDebug("Sending request: \n\(String(reflecting: request))")

		request.validate(statusCode: 200..<401).responseData { dataResult in
			let httpResponse = dataResult.response
			if let error = dataResult.error {
				MMLogWarn("""
					Error while performing request
					\(error.localizedDescription)
					""")
				completion(httpResponse, nil, error as NSError)
				return
			}

			guard let response = dataResult.response else {
				MMLogWarn("""
						Empty response received
						""")
				completion(httpResponse, nil, nil)
				return
			}

			guard let data = dataResult.data else {
				MMLogWarn("""
					Empty data received
					url: \(response.url.orNil)
					status code: \(response.statusCode)
					headers: \(String(describing: response.allHeaderFields))
					""")
				completion(httpResponse, nil, MMInternalErrorType.UnknownError.foundationError)
				return
			}

			MMLogDebug("""
				Response received
				url: \(response.url.orNil)
				status code: \(response.statusCode)
				headers: \(String(describing: response.allHeaderFields))
				data: \(String(data: data, encoding: String.Encoding.utf8).orNil)
				""")

			let responseJson = JSON(data: data)
			completion(httpResponse, responseJson, RequestError(json: responseJson)?.foundationError)
		}
	}

	func sendRequest<R: RequestData>(_ r: R, completion: @escaping (JSON?, NSError?) -> Void) {
		getDataResponse(r) { httpResponse, json, error in
			self.handleDynamicBaseUrl(response: httpResponse, error: error as NSError?)
			completion(json, error)
		}
	}

	func handleDynamicBaseUrl(response: URLResponse?, error: NSError?) {
		if let error = error, error.mm_isCannotFindHost {
			storeDynamicBaseUrl(nil)
			dynamicBaseUrl = originalBaseUrl
		} else {
			if let httpResponse = response as? HTTPURLResponse, let newBaseUrlString = httpResponse.allHeaderFields[Consts.DynamicBaseUrlConsts.newBaseUrlHeader] as? String, let newDynamicBaseUrl = URL(string: newBaseUrlString) {
				storeDynamicBaseUrl(newDynamicBaseUrl)
				dynamicBaseUrl = newDynamicBaseUrl
			}
		}
	}
}
