//
//  MMHTTPRequestSerializer.swift
//  MobileMessaging
//
//  Created by okoroleva on 07.03.16.
//  

import MMAFNetworking

final class MMHTTPRequestSerializer : MM_AFHTTPRequestSerializer {
	private var applicationCode: String
    private var jsonBody: [String: AnyObject]?
	private var headers: [String: String]?
    
    init(applicationCode: String, jsonBody: [String: AnyObject]?, headers: [String: String]?) {
		self.applicationCode = applicationCode
        self.jsonBody = jsonBody
		self.headers = headers
		super.init()
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
    override var HTTPMethodsEncodingParametersInURI : Set<String> {
        get {
            var params = super.HTTPMethodsEncodingParametersInURI
            params.insert("POST")
            return params
        }
        set {}
	}
	
	func applyHeaders(inout request: NSMutableURLRequest) {
		if let headers = headers {
			for (header, value) in headers {
				request.addValue(value, forHTTPHeaderField: header)
			}
		}
		request.addValue("App \(applicationCode)", forHTTPHeaderField: "Authorization")
		request.addValue(MMUserAgent.currentUserAgent, forHTTPHeaderField: "User-Agent")
		if NSProcessInfo.processInfo().arguments.contains("-UseIAMMocks") {
			request.addValue("iam-mock", forHTTPHeaderField: "Accept-Features")
		}
	}
	
    override func requestWithMethod(method: String, URLString: String, parameters: AnyObject?, error: NSErrorPointer) -> NSMutableURLRequest {
        var request = NSMutableURLRequest()
		request.timeoutInterval = 20
        request.HTTPMethod = method
		request.URL = URL(withQueryParameters: parameters, url: URLString)
		applyHeaders(&request)
		
        if let jsonBody = jsonBody where method == "POST" {
            var data : NSData?
            do {
                data = try NSJSONSerialization.dataWithJSONObject(jsonBody, options: [])
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.addValue("application/json", forHTTPHeaderField: "Accept")
                request.HTTPBody = data
            } catch let error as NSError {
                MMLogError("RequestSerializer can't serialize json body: \(jsonBody) with error: \(error)")
            }
        }
        
        return request;
    }
	
	func URL(withQueryParameters parameters: AnyObject?, url: String) -> NSURL? {
		var completeURLString = url
		if let dictParams = parameters as? [String : AnyObject] {
			completeURLString += "?" + MMHTTPRequestSerializer.queryFromParameters(dictParams);
		}
		return NSURL(string: completeURLString)
	}
	
	class func queryFromParameters(parameters: [String: AnyObject]) -> String {
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
				escapedPairs.append("\(key.mm_escapeString())=\(String(value).mm_escapeString())")
			}
		}
		return escapedPairs.joinWithSeparator("&")
	}
}