//
//  RequestSerializer.swift
//  MobileMessaging
//
//  Created by okoroleva on 07.03.16.
//

final class RequestSerializer : MM_AFHTTPRequestSerializer {
	private var applicationCode: String
    private var jsonBody: [String: Any]?
	private var headers: [String: String]?
    
    init(applicationCode: String, jsonBody: [String: Any]?, headers: [String: String]?) {
		self.applicationCode = applicationCode
        self.jsonBody = jsonBody?.nilIfEmpty
		self.headers = headers
		super.init()
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
    override var httpMethodsEncodingParametersInURI : Set<String> {
        get {
            var params = super.httpMethodsEncodingParametersInURI
            params.insert("POST")
            return params
        }
        set {}
	}
	
	func applyHeaders(_ request: inout NSMutableURLRequest) {
		headers?.forEach { (hv) in
			request.addValue(hv.value, forHTTPHeaderField: hv.key)
		}
		request.addValue("App \(applicationCode)", forHTTPHeaderField: "Authorization")
		request.addValue(MobileMessaging.userAgent.currentUserAgentString, forHTTPHeaderField: "User-Agent")
		request.addValue(String(UIApplication.shared.isInForegroundState), forHTTPHeaderField: APIHeaders.foreground)
		if let internalId = MobileMessaging.currentUser?.pushRegistrationId {
			request.addValue(internalId, forHTTPHeaderField: APIHeaders.pushRegistrationId)
		}
	}
	
	override func request(withMethod method: String, urlString URLString: String, parameters: Any?, error: NSErrorPointer) -> NSMutableURLRequest {
        var request = NSMutableURLRequest()
		request.timeoutInterval = 20
        request.httpMethod = method
		request.url = makeURL(withQueryParameters: parameters, url: URLString)
		applyHeaders(&request)
		
        if let jsonBody = jsonBody , method == "POST" {
            do {
                request.httpBody = try SanitizedJSONSerialization.data(withJSONObject: jsonBody, options: [])
				request.addValue("application/json", forHTTPHeaderField: "Content-Type")
				request.addValue("application/json", forHTTPHeaderField: "Accept")
            } catch let error as NSError {
                MMLogError("RequestSerializer can't serialize json body: \(jsonBody) with error: \(error)")
            }
        }
		
        return request;
    }
	
	func makeURL(withQueryParameters parameters: Any?, url: String) -> URL? {
		var completeURLString: String = url
		if let dictParams = parameters as? [String: AnyObject] {
			completeURLString += "?" + RequestSerializer.query(fromParameters: dictParams);
		}
		return URL(string: completeURLString)
	}
	
	class func query(fromParameters parameters: [String: Any]) -> String {
		var escapedPairs = [String]()
		for (key, value) in parameters {
			switch value {
			case let _value as String :
				escapedPairs.append("\(key.mm_urlSafeString)=\(_value.mm_urlSafeString)")
			case (let _values as [String]) :
				for arrayValue in _values {
					escapedPairs.append("\(key.mm_urlSafeString)=\(arrayValue.mm_urlSafeString)")
				}
			default:
				escapedPairs.append("\(key.mm_urlSafeString)=\(String(describing: value).mm_urlSafeString)")
			}
		}
		return escapedPairs.joined(separator: "&")
	}
}

class SanitizedJSONSerialization: JSONSerialization {
	override class func data(withJSONObject obj: Any, options opt: JSONSerialization.WritingOptions = []) throws -> Data {
		let data = try super.data(withJSONObject: obj, options: opt)
		let jsonString = String(data: data, encoding: String.Encoding.utf8)
		let sanitizedString = jsonString?.replacingOccurrences(of: "\\/", with: "/")
		return sanitizedString?.data(using: String.Encoding.utf8) ?? Data()
	}
}
