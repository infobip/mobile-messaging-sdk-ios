//
//  Mocks.swift
//  MobileMessagingExample
//
//  Created by okoroleva on 07.12.16.
//

@testable import MobileMessaging

extension JSON {
	func requestJsonMatches(requestResponseMock: RequestResponseMock) -> Bool {
		var requestJsonMock = requestResponseMock.requestJson.dictionary
		
		if var mockHeaders = requestJsonMock?["headers"]?.dictionaryObject as? [String: String], var selfHeaders = self["headers"].dictionaryObject as? [String: String] {
			
			
			
			selfHeaders = selfHeaders.reduce([:], { (result, kv: (key: String, value: String)) -> [String: String] in
				var result = result
				result[kv.key.lowercased()] = kv.value.lowercased()
				return result
			})
			
			mockHeaders = mockHeaders.reduce([:], { (result, kv: (key: String, value: String)) -> [String: String] in
				var result = result
				result[kv.key.lowercased()] = kv.value.lowercased()
				return result
			})
			
			for (k,v) in mockHeaders {
				if selfHeaders[k.lowercased()] != v {
					return false
				}
			}
		}
		
		guard
			let requestWoHeaders = { _ -> [String: JSON]? in
				var ret = self.dictionary
				_ = ret?.removeValue(forKey: "headers")
				return ret
			}(),
			
			let requestMockWoHeaders = { _ -> [String: JSON]? in
				var ret = requestJsonMock
				_ = ret?.removeValue(forKey: "headers")
				return ret
			}()
		
			else
		{
			return false
		}
		return requestWoHeaders == requestMockWoHeaders
		
/*
		po requestJsonMock.debugDescription
		"{\n  \"headers\" : {\n    \"authorization\" : \"App someCorrectApplicationID\",\n    \"pushregistrationid\" : \"someExistingInternalID\"\n  },\n  \"requestBody\" : {\n    \"drIDs\" : [\n      \"m1\"\n    ]\n  },\n  \"parameters\" : {\n    \"platformType\" : \"APNS\"\n  }\n}"

*/
//		let selfDict = self.dictionary
//		if let requestJsonMockDict = requestJsonMock.dictionary {
//			for (key, val) in requestJsonMockDict {
//				if selfDict?[key] != val {
//					return false
//				}
//			}
//		} else {
//			return false
//		}
//		return true
	}
}

class Mocks {
	static func mockedResponseForRequest<T: RequestData>(request: T, appCode: String) -> JSON? {
		
		let fm = FileManager()
		let path = Bundle.init(for: self).bundlePath + "/mocks\(request.path.rawValue)/\(request.method.rawValue).json"
		guard fm.fileExists(atPath: path), let mocksFileContent = fm.contents(atPath: path) else {
			return Mocks.mockNotFoundJSON
		}
		let mocksJson = JSON(data: mocksFileContent)
		guard let mocks = mocksJson[MockKeys.mocksArray].array else {
			return Mocks.mockNotFoundJSON
		}
		
		// headers are being formed by request serializer, so use it:
		let urlRequest: NSMutableURLRequest = RequestSerializer(applicationCode: appCode, jsonBody: request.body, headers: request.headers).request(withMethod: request.method.rawValue, urlString: "any", parameters: request.parameters, error: nil)
		let headers = urlRequest.allHTTPHeaderFields
		
		let requestJson = requestJSON(headers: headers, queryParameters: request.parameters, body: request.body)
		let requestResponseMocks = mocks.map { RequestResponseMock(mock: $0) }
		MMLogDebug("[Mocks] request: \(request.path.rawValue)/\(request.method.rawValue).json \(requestJson)")
		for requestResponseMock in requestResponseMocks {
			if requestJson.requestJsonMatches(requestResponseMock: requestResponseMock) {
				MMLogDebug("[Mocks] response: \(requestResponseMock.responseJson)")
				return requestResponseMock.responseJson
			}
		}
		
		if let defaultResponse = requestResponseMocks.filter({ $0.isDefault }).first?.responseJson {
			MMLogDebug("[Mocks] Default response: \(defaultResponse)")
			return defaultResponse
		}
		return Mocks.mockNotFoundJSON
	}
	
	private static func requestJSON(headers: [String: String]?, queryParameters: [String: Any]?, body: [String: Any]?) -> JSON {
		var ret = JSON([:])
		if let headers = headers, !headers.isEmpty {
			ret[MockKeys.headers] = JSON(headers)
		}
		if let queryParameters = queryParameters, !queryParameters.isEmpty {
			ret[MockKeys.parameters] = JSON(queryParameters)
		}
		if let body = body, !body.isEmpty {
			ret[MockKeys.requestBody] = JSON(body)
		}
		return ret
	}
	
	private static var mockNotFoundJSON: JSON {
		MMLogDebug("[Mocks] not found")
		return JSON("\"requestError\": {\"serviceException\": {\"text\": \"Local mock not found\", \"messageId\": \"0\"}}")
	}
}

struct MockKeys {
	static let mocksArray = "mocks"
	static let headers = "headers"
	static let authorization = "authorization"
	static let parameters = "parameters"
	static let responseBody = "responseBody"
	static let requestBody = "requestBody"
	static let responseStatus = "responseStatus"
	static let defaultMock = "default"
	static let pushregistrationid = "pushregistrationid"
}

class RequestResponseMock {
	let isDefault: Bool
	let requestJson: JSON
	let responseJson: JSON
	init(mock: JSON) {
		var ret = JSON([:])
		let headers = mock[MockKeys.headers]
		if !headers.isEmpty {
			ret[MockKeys.headers] = headers
		}
		
		let queryParameters = mock[MockKeys.parameters]
		if !queryParameters.isEmpty {
			ret[MockKeys.parameters] = queryParameters
		}
		
		let body = mock[MockKeys.requestBody]
		if !body.isEmpty {
			ret[MockKeys.requestBody] = body
		}

		self.requestJson = ret
		
		var respDict = [MockKeys.responseStatus: mock[MockKeys.responseStatus]]
		respDict += mock[MockKeys.responseBody].dictionary
		self.responseJson = JSON(respDict)
		self.isDefault = mock[MockKeys.defaultMock].bool ?? false
	}
}
