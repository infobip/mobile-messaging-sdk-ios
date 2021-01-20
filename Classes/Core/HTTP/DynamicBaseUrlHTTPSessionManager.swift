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

struct JSONRequestEncoding: ParameterEncoding {
	let request: RequestData
	func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
		var urlRequest = try urlRequest.asURLRequest()
		if let jsonBody = request.body {
			urlRequest.httpBody = try SanitizedJSONSerialization.data(withJSONObject: jsonBody, options: [])
		}
		urlRequest = try URLEncoding.queryString.encode(urlRequest, with: parameters)
		return urlRequest
	}
}

class DynamicBaseUrlHTTPSessionManager {
	var dynamicBaseUrl: URL?
	var originalBaseUrl: URL
	let configuration: URLSessionConfiguration
	let alamofireSessionManager: SessionManager

	let appGroupId: String?
	var storage: UserDefaults

	init(baseURL url: URL, sessionConfiguration configuration: URLSessionConfiguration?, appGroupId: String?) {
		self.configuration = configuration ?? URLSessionConfiguration.default
		self.configuration.timeoutIntervalForResource = 20
		self.configuration.timeoutIntervalForRequest = 20
		self.alamofireSessionManager = SessionManager(configuration: self.configuration)
		self.originalBaseUrl = url
		self.appGroupId = appGroupId
		if let appGroupId = appGroupId, let sharedUserDefaults = UserDefaults(suiteName: appGroupId) {
			self.storage = sharedUserDefaults
		} else {
			self.storage = UserDefaults.standard
		}

		self.dynamicBaseUrl = getStoredDynamicBaseUrl() ?? url
	}

	private func storeDynamicBaseUrl(_ url: URL?) {
		if let url = url {
			storage.set(url, forKey: Consts.DynamicBaseUrlConsts.storedDynamicBaseUrlKey)
		} else {
			storage.removeObject(forKey: Consts.DynamicBaseUrlConsts.storedDynamicBaseUrlKey)
			storage.synchronize()
		}
	}

	private func getStoredDynamicBaseUrl() -> URL? {
		return storage.url(forKey: Consts.DynamicBaseUrlConsts.storedDynamicBaseUrlKey)
	}

	func url(_ r: RequestData) -> String {
		return (dynamicBaseUrl ?? originalBaseUrl).absoluteString + r.resolvedPath
	}

	func getDataResponse(_ r: RequestData, completion: @escaping (JSON?, NSError?) -> Void) {
		let request = alamofireSessionManager.request(url(r), method: r.method, parameters: r.parameters, encoding: JSONRequestEncoding(request: r), headers: r.headers)
		MMLogDebug("Sending request: \n\(String(reflecting: request))")

		request.validate().responseData { dataResult in
			let error = dataResult.error as NSError?
			self.handleDynamicBaseUrl(response: dataResult.response, error: error)

			guard let response = dataResult.response else {
				MMLogWarn("Empty response received")
				completion(nil, error)
				return
			}

			guard let data = dataResult.data else {
				MMLogWarn("""
					Empty data received
					url: \(response.url.orNil)
					status code: \(response.statusCode)
					headers: \(String(describing: response.allHeaderFields))
					""")
				completion(nil, error)
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

			if let serviceError = RequestError(json: responseJson) {
				MMLogWarn("""
				Service error while performing request:
				\(serviceError)
				""")
				completion(responseJson, serviceError.foundationError)
			} else {
				completion(responseJson, error)
			}
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
