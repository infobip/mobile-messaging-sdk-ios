//
//  MMResponseSerializer.swift
//
//  Created by Andrey K. on 14/04/16.
//
//

import MMAFNetworking
import SwiftyJSON

final class MMResponseSerializer<T: JSONDecodable> : MM_AFHTTPResponseSerializer {
	override init() {
		super.init()
		let range: NSRange = NSMakeRange(200, 100)
		self.acceptableStatusCodes = NSIndexSet(indexesInRange: range)
	}
	
	override func responseObjectForResponse(response: NSURLResponse?, data: NSData?, error: NSErrorPointer) -> AnyObject? {
		MMLogDebug("Response received: \(response)")
		super.responseObjectForResponse(response, data: data, error: error)
		
		guard let data = data else
		{
			return nil
		}
		
		let json = JSON(data: data)
		if let requestError = MMRequestError(json: json) where response?.isFailureHTTPREsponse ?? false {
			error.memory = requestError.foundationError
		}
		return T(json: json) as? AnyObject
	}
}

extension NSURLResponse {
	var isFailureHTTPREsponse: Bool {
		var statusCodeIsError = false
		if let httpResponse = self as? NSHTTPURLResponse {
			statusCodeIsError = NSIndexSet(indexesInRange: NSMakeRange(200, 100)).containsIndex(httpResponse.statusCode) == false
		}
		return statusCodeIsError
	}
}
