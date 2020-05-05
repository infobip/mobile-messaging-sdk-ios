//
//  ChatJSWrapper.swift
//  MobileMessaging
//
//  Created by okoroleva on 24.04.2020.
//

import Foundation
import WebKit

protocol ChatJSWrapper {
	func sendMessage(_ message: String)
}

extension WKWebView: ChatJSWrapper {
	func sendMessage(_ message: String) {
		guard let escaped = message.javaScriptEscapedString() else {
			MMLogDebug("[InAppChat] sendMessage failed, can't escape a message \(message)")
			return
		}
		self.evaluateJavaScript("sendMessage(\(escaped))") { (response, error) in
			MMLogDebug("[InAppChat] sendMessage call got a response: \(response.debugDescription), error: \(error?.localizedDescription ?? "")")
		}
	}
}

extension String
{
    func javaScriptEscapedString() -> String?
    {
        let data = try! JSONSerialization.data(withJSONObject:[self], options: [])
		if let encodedString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
			return encodedString.substring(with: NSMakeRange(1, encodedString.length - 2))
		}
        return nil
    }
}
