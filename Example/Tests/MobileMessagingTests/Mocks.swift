//
//  Mocks.swift
//  MobileMessagingExample
//
//  Created by okoroleva on 07.12.16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

@testable import MobileMessaging

class Mocks {
	static func mockedResponseForRequest<T: RequestData>(request: T, appCode: String) -> JSON? {
		
		let fm = FileManager()
		let path = Bundle.init(for: self).bundlePath + "/mocks\(request.path.rawValue)/\(request.method.rawValue).json"
		guard fm.fileExists(atPath: path), let content = fm.contents(atPath: path) else {
			return mockNotFound()
		}
		
		let fullJson = JSON(data: content)
		guard let mocks = fullJson[MockKeys.mocksArray].array else {
			return mockNotFound()
		}
		
		let requestJson = jsonToCompareWithMock(appCode: appCode, request: request)
		let requestMocks = mocks.map{RequestMock(mock: $0)}
		MMLogDebug("[Mocks] request: \(request.path.rawValue)/\(request.method.rawValue).json \(requestJson)")
		for requestMock in requestMocks {
			if requestJson == requestMock.requestJson {
				MMLogDebug("[Mocks] response: \(requestMock.responseJson)")
				return requestMock.responseJson
			}
		}
		
		if let defaultResponse = requestMocks.filter({ $0.isDefault }).first?.responseJson {
			MMLogDebug("[Mocks] Default response: \(defaultResponse)")
			return defaultResponse
		}
		return mockNotFound()
	}
	
	private static func jsonToCompareWithMock<T: RequestData>(appCode: String, request: T) -> JSON {
		let headers = request.headers + [MockKeys.authorization: "App \(appCode)"]
		
		return JSON([
			MockKeys.headers: headers,
			MockKeys.parameters: request.parameters,
			MockKeys.requestBody: request.body
			])
	}
	
	private static func mockNotFound() -> JSON {
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
}

class RequestMock {
	let isDefault: Bool
	let requestJson: JSON
	let responseJson: JSON
	init(mock: JSON) {
		self.requestJson = JSON([MockKeys.headers: mock[MockKeys.headers],
		                        MockKeys.parameters: mock[MockKeys.parameters],
		                        MockKeys.requestBody: mock[MockKeys.requestBody]])
		
		var respDict = [MockKeys.responseStatus: mock[MockKeys.responseStatus]]
		respDict += mock[MockKeys.responseBody].dictionary
		self.responseJson = JSON(respDict)
		self.isDefault = mock[MockKeys.defaultMock].bool ?? false
	}
}

protocol MockedRequest: RequestData {
	func jsonToCompareWithMock(appCode: String) -> JSON
}

extension MockedRequest {
	func jsonToCompareWithMock(appCode: String) -> JSON {
		let headers = self.headers + [MockKeys.authorization: "App \(appCode)"]
		
		return JSON([
			MockKeys.headers: headers,
			MockKeys.parameters: self.parameters,
			MockKeys.requestBody: self.body
			])
	}
}
