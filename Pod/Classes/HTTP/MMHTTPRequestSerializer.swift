//
//  RequestSerializer.swift
//  MobileMessaging
//
//  Created by okoroleva on 07.03.16.
//
import MobileMessaging.Private

final class RequestSerializer : MM_AFHTTPRequestSerializer {
	private var applicationCode: String
    private var jsonBody: [String: Any]?
	private var headers: [String: String]?
    
    init(applicationCode: String, jsonBody: [String: Any]?, headers: [String: String]?) {
		self.applicationCode = applicationCode
        self.jsonBody = jsonBody
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
		if let headers = headers {
			for (header, value) in headers {
				request.addValue(value, forHTTPHeaderField: header)
			}
		}
		request.addValue("App \(applicationCode)", forHTTPHeaderField: "Authorization")
		request.addValue(MobileMessaging.userAgent.currentUserAgentString, forHTTPHeaderField: "User-Agent")
	}
	

	override func request(withMethod method: String, urlString URLString: String, parameters: Any?, error: NSErrorPointer) -> NSMutableURLRequest {
        var request = NSMutableURLRequest()
		request.timeoutInterval = 20
        request.httpMethod = method
		request.url = makeURL(withQueryParameters: parameters, url: URLString)
		applyHeaders(&request)
		
        if let jsonBody = jsonBody , method == "POST" {
            var data : Data?
            do {
                data = try SanitizedJSONSerialization.data(withJSONObject: jsonBody, options: [])
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.addValue("application/json", forHTTPHeaderField: "Accept")
                request.httpBody = data
            } catch let error as NSError {
                MMLogError("RequestSerializer can't serialize json body: \(jsonBody) with error: \(error)")
            }
        }
        
        return request;
    }
	
	func makeURL(withQueryParameters parameters: Any?, url: String) -> URL? {
		var completeURLString = url
		if let dictParams = parameters as? [String : AnyObject] {
			completeURLString += "?" + RequestSerializer.query(fromParameters: dictParams);
		}
		return URL(string: completeURLString)
	}
	
	class func query(fromParameters parameters: [String: Any]) -> String {
		var escapedPairs = [String]()
		for (key, value) in parameters {
			switch value {
			case let _value as String :
				escapedPairs.append("\(key.mm_escapeString())=\(_value.mm_escapeString())")
			case (let _values as [String]) :
				for arrayValue in _values {
					escapedPairs.append("\(key.mm_escapeString())=\(arrayValue.mm_escapeString())")
				}
			default:
				escapedPairs.append("\(key.mm_escapeString())=\(String(describing: value).mm_escapeString())")
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
