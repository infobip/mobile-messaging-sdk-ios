//
//  MMResponseSerializer.swift
//
//  Created by Andrey K. on 14/04/16.
//
//

//import SwiftyJSON

final class MMResponseSerializer<T: JSONDecodable> : MM_AFHTTPResponseSerializer {
	override init() {
		super.init()
		self.acceptableStatusCodes = IndexSet(integersIn: 200..<300)
	}

	required init?(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}
	
	override func responseObject(for response: URLResponse?, data: Data?, error: NSErrorPointer) -> Any? {
		MMLogDebug("Response received: \(response)")
		super.responseObject(for: response, data: data, error: error)
		
		guard let data = data else
		{
			return nil
		}
		
		let json = JSON(data: data as Data)
		if let requestError = MMRequestError(json: json) , response?.isFailureHTTPREsponse ?? false {
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
