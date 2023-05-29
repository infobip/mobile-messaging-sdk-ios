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

public class DynamicBaseUrlHTTPSessionManager: NamedLogger {
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

	func resolveUrl(_ r: RequestData) -> String {
        return (r.baseUrl ?? actualBaseUrl()).absoluteString + r.resolvedPath
	}
    
    func actualBaseUrl() -> URL {
        return dynamicBaseUrl ?? originalBaseUrl
    }

    func getDataResponse(_ r: RequestData, queue: DispatchQueue, completion: @escaping (JSON?, NSError?) -> Void) {
		let request = alamofireSessionManager.request(resolveUrl(r), method: r.method, parameters: r.parameters, encoding: JSONRequestEncoding(request: r), headers: r.headers)
		logDebug("Sending request: \n\(String(reflecting: request))")

        request.validate().responseData(queue: queue) { dataResult in
			let error = dataResult.error as NSError?
			self.handleDynamicBaseUrl(response: dataResult.response, error: error)

			guard let response = dataResult.response else {
                self.logWarn("Empty response received")
				completion(nil, error)
				return
			}

			guard let data = dataResult.data else {
                self.logWarn("""
					Empty data received
					url: \(response.url.orNil)
					status code: \(response.statusCode)
					headers: \(String(describing: response.allHeaderFields))
					""")
				completion(nil, error)
				return
			}

            self.logDebug("""
				Response received
				url: \(response.url.orNil)
				status code: \(response.statusCode)
				headers: \(String(describing: response.allHeaderFields))
				data: \(String(data: data, encoding: String.Encoding.utf8).orNil)
				""")

			let responseJson = JSON(data: data)

			if let serviceError = MMRequestError(json: responseJson) {
                self.logWarn("""
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
			resetBaseUrl()
		} else {
			if let httpResponse = response as? HTTPURLResponse, let newBaseUrlString = httpResponse.allHeaderFields[Consts.DynamicBaseUrlConsts.newBaseUrlHeader] as? String, let newDynamicBaseUrl = URL(string: newBaseUrlString) {
				setNewBaseUrl(newBaseUrl: newDynamicBaseUrl)
			}
		}
	}
    
    func resetBaseUrl() {
        storeDynamicBaseUrl(nil)
        dynamicBaseUrl = originalBaseUrl
    }
    
    func setNewBaseUrl(newBaseUrl: URL) {
        if newBaseUrl != dynamicBaseUrl {
            logDebug("Setting new base URL \(newBaseUrl)")
            storeDynamicBaseUrl(newBaseUrl)
            dynamicBaseUrl = newBaseUrl
            if newBaseUrl != originalBaseUrl {
                // We force server syncing in case a new base URL different than original one is set
                MobileMessaging.sharedInstance?.baseUrlDidChange()
            }
        } else {
            logDebug("Base URL remained the same \(newBaseUrl)")
        }
    }
}
