//
//  ChatJSWrapper.swift
//  MobileMessaging
//
//  Created by okoroleva on 24.04.2020.
//

import Foundation
import WebKit

protocol ChatJSWrapper {
    func sendMessage(_ message: String?, attachment: ChatMobileAttachment?)
    func sendDraft(_ message: String?)
}

extension WKWebView: NamedLogger {}
extension WKWebView: ChatJSWrapper {
    func sendMessage(_ message: String? = nil, attachment: ChatMobileAttachment? = nil) {
        let escapedMessage = message?.javaScriptEscapedString()
        guard escapedMessage != nil || attachment != nil else {
			logDebug("sendMessage failed, neither message nor the attachment provided")
			return
		}
        self.evaluateJavaScript("sendMessage(\(escapedMessage ?? "''"), '\(attachment?.base64UrlString() ?? "")', '\(attachment?.fileName ?? "")')") { (response, error) in
			self.logDebug("sendMessage call got a response: \(response.debugDescription), error: \(error?.localizedDescription ?? "")")
		}
	}
    
    func sendDraft(_ message: String?) {
        let escapedMessage = message?.javaScriptEscapedString()
        guard escapedMessage != nil else {
            logDebug("sendDraft failed, message not provided")
            return
        }
        
        self.evaluateJavaScript("sendDraft(\(escapedMessage ?? ""))"){
            (response, error) in
            self.logDebug("sendDraft call got a response:\(response.debugDescription), error: \(error?.localizedDescription ?? "")")
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
