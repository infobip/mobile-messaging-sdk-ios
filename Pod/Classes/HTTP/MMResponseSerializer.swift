//
//  MMResponseSerializer.swift
//
//  Created by Andrey K. on 14/04/16.
//
//

import MMAFNetworking
import Freddy

final class MMResponseSerializer<T: JSONDecodable> : MM_AFHTTPResponseSerializer {
	override init() {
		super.init()
		let range: NSRange = NSMakeRange(200, 99)
		self.acceptableStatusCodes = NSIndexSet(indexesInRange: range)
	}
	
	override func responseObjectForResponse(response: NSURLResponse?, data: NSData?, error: NSErrorPointer) -> AnyObject? {
		MMLogInfo("Response received: \(response)")
		super.responseObjectForResponse(response, data: data, error: error)
		
		guard let data = data, let json = try? JSON(data: data) else {
			return nil
		}
		
		if let requestError = try? MMRequestError(json: json) {
			error.memory = requestError.foundationError
		}
		
		return (try? T(json: json)) as? AnyObject
	}
}
