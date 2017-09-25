//
//  MMResponseSerializer.swift
//
//  Created by Andrey K. on 14/04/16.
//
//


final class ResponseSerializer<T: JSONDecodable> : MM_AFHTTPResponseSerializer {
	override init() {
		super.init()
		self.acceptableStatusCodes = IndexSet(integersIn: 200..<300)
	}

	required init?(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}
	
	override func responseObject(for response: URLResponse?, data: Data?, error: NSErrorPointer) -> Any? {
		super.responseObject(for: response, data: data, error: error)
		
		guard let response = response,
			  let data = data else {
				return nil
		}
		let dataString = String(data: data, encoding: String.Encoding.utf8)
		
		MMLogDebug("Response received: \(response)\n\(String(describing: dataString))")
		
		let json = JSON(data: data)
		if let requestError = RequestError(json: json) ,response.isFailureHTTPREsponse {
			error?.pointee = requestError.foundationError
		}
		return T(json: json)
	}
}

extension URLResponse {
	var isFailureHTTPREsponse: Bool {
		var statusCodeIsError = false
		if let httpResponse = self as? HTTPURLResponse {
			statusCodeIsError = IndexSet(integersIn: 200..<300).contains(httpResponse.statusCode) == false
		}
		return statusCodeIsError
	}
}
