//
//  DynamicBaseUrlHTTPSessionManager.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2026 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

public class DynamicBaseUrlHTTPSessionManager: NamedLogger {
	private var _dynamicBaseUrl: URL?
	private let baseUrlQueue = DispatchQueue(label: "com.infobip.mobilemessaging.baseurl", qos: .userInitiated)

	var dynamicBaseUrl: URL? {
		get {
			return baseUrlQueue.sync { _dynamicBaseUrl }
		}
		set {
			baseUrlQueue.sync { _dynamicBaseUrl = newValue }
		}
	}

	var originalBaseUrl: URL
	let configuration: URLSessionConfiguration
	let urlSession: URLSession

	let appGroupId: String?
	var storage: UserDefaults

	init(baseURL url: URL, sessionConfiguration configuration: URLSessionConfiguration?, appGroupId: String?) {
        self.configuration = configuration ?? MobileMessaging.urlSessionConfiguration
		self.configuration.timeoutIntervalForResource = 20
		self.configuration.timeoutIntervalForRequest = 20
        self.configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.configuration.urlCache = nil
		self.urlSession = URLSession(configuration: self.configuration)
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
			storage.set(url, forKey: Consts.DynamicBaseUrl.storedDynamicBaseUrlKey)
		} else {
			storage.removeObject(forKey: Consts.DynamicBaseUrl.storedDynamicBaseUrlKey)
			storage.synchronize()
		}
	}

	private func getStoredDynamicBaseUrl() -> URL? {
		return storage.url(forKey: Consts.DynamicBaseUrl.storedDynamicBaseUrlKey)
	}

    public func actualBaseUrl() -> URL {
        return dynamicBaseUrl ?? originalBaseUrl
    }

    func getDataResponse(_ r: RequestData, queue: DispatchQueue, completion: @escaping (JSON?, NSError?) -> Void) {
        let baseURL = r.baseUrl ?? actualBaseUrl()

        let urlRequest: URLRequest
        do {
            urlRequest = try r.buildURLRequest(baseURL: baseURL)
        } catch {
            queue.async { completion(nil, error as NSError) }
            return
        }

        logDebug("Sending request: \(urlRequest.httpMethod ?? "?") \(urlRequest.url?.absoluteString ?? "nil")")

        let task = urlSession.dataTask(with: urlRequest) { [weak self] data, response, error in
            queue.async {
                guard let self = self else { return }
                let nsError = error as NSError?
                self.handleDynamicBaseUrl(response: response, error: nsError)

                guard let httpResponse = response as? HTTPURLResponse else {
                    self.logWarn("Empty response received")
                    completion(nil, nsError)
                    return
                }

                // #1 - Validation of the status code (to filter out errors)
                guard (200..<300).contains(httpResponse.statusCode) else {
                    // it is error
                    let statusError = NSError(
                        domain: "com.mobile-messaging.http",
                        code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "Request failed with status code \(httpResponse.statusCode)"]
                    )
                    
                    guard let data = data, !data.isEmpty else {
                        // we have no data about the error: we propagate the base NSError
                        completion(nil, statusError)
                        return
                    }
                    
                    // we have json data about the error, and try to generate a MMRequestError with it
                    let responseJson = JSON(data: data)
                    guard let serviceError = MMRequestError(json: responseJson) else {
                        completion(nil, statusError)
                        return
                    }
                    
                    self.logWarn("Service error while performing request:\(serviceError)")
                    completion(responseJson, serviceError.foundationError)
                    return
                }

                // #2 - Validation of the Content-Type validation (to detect unexpected responses)
                guard let data = data, !data.isEmpty else {
                    self.logDebug("""
                        Empty data received
                        url: \(httpResponse.url.orNil)
                        status code: \(httpResponse.statusCode)
                        headers: \(String(describing: httpResponse.allHeaderFields))
                        """)
                    completion(nil, nsError)
                    return
                }
                
                if let mimeType = httpResponse.mimeType, !mimeType.contains("json") {
                    let contentTypeError = NSError(
                        type: .UnknownError,
                        description: "Unexpected Content-Type: \(mimeType)"
                    )
                    completion(nil, contentTypeError)
                    return
                }

                self.logDebug("""
                    Response received
                    url: \(httpResponse.url.orNil)
                    status code: \(httpResponse.statusCode)
                    headers: \(String(describing: httpResponse.allHeaderFields))
                    data: \(String(data: data, encoding: String.Encoding.utf8).orNil)
                    """)

                let responseJson = JSON(data: data)

                if let serviceError = MMRequestError(json: responseJson) {
                    self.logWarn("Service error while performing request: \(serviceError)")
                    completion(responseJson, serviceError.foundationError)
                } else {
                    completion(responseJson, nsError)
                }
            }
        }
        task.resume()
	}

    func handleDynamicBaseUrl(response: URLResponse?, error: NSError?) {
		if let error = error, error.mm_isCannotFindHost {
            logDebug("Cannot find host, resetting dynamic base URL")
			resetBaseUrl()
		} else {
			if let httpResponse = response as? HTTPURLResponse, let newBaseUrlString = httpResponse.value(forHTTPHeaderField: Consts.DynamicBaseUrl.newBaseUrlHeader), let newDynamicBaseUrl = URL(string: newBaseUrlString) {
				setNewBaseUrl(newBaseUrl: newDynamicBaseUrl)
			}
		}
	}

    func resetBaseUrl() {
        storeDynamicBaseUrl(nil)
        dynamicBaseUrl = originalBaseUrl
    }

    func setNewBaseUrl(newBaseUrl: URL) {
        let didChange = baseUrlQueue.sync { () -> Bool in
            guard newBaseUrl != _dynamicBaseUrl else { return false }
            _dynamicBaseUrl = newBaseUrl
            return true
        }
        if didChange {
            logDebug("Setting new base URL \(newBaseUrl)")
            storeDynamicBaseUrl(newBaseUrl)
            if newBaseUrl != originalBaseUrl {
                MobileMessaging.sharedInstance?.baseUrlDidChange()
            }
        } else {
            logDebug("Base URL remained the same \(newBaseUrl)")
        }
    }
}
