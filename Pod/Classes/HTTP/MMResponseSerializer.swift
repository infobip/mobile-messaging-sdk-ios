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
		
		guard let data = data else {
			return nil
		}
		
		guard let json = try? JSON(data: data) else {
			return nil
		}
		
		if let errorValue = error.memory {
			var userInfo = Dictionary<NSObject, AnyObject>()
			
			if let jsonDict = try? json.dictionary() {
				userInfo = jsonDictToNormalDict(jsonDict)
				if let errorDescr = errorDescription(json) {
					userInfo[NSLocalizedDescriptionKey] = errorDescr
				}
			} else {
				userInfo = errorValue.userInfo
			}
			error.memory = NSError(domain: errorValue.domain, code: errorValue.code, userInfo: userInfo)
		}
		
		return (try? T(json: json)) as? AnyObject
	}
	
	private func errorDescription(json: JSON) -> String? {
		guard let requestError = try? json.dictionary(MMAPIKeys.kRequestError),
			let serviceException = requestError[MMAPIKeys.kServiceException] else {
				return nil
		}
		return try? serviceException.string(MMAPIKeys.kErrorText)
	}
}
