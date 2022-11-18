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
    func setLanguage(_ language: MMLanguage?)
    func sendContextualData(_ metadata: String, multiThreadStrategy: MMChatMultiThreadStrategy,
                            completion: @escaping (_ error: NSError?) -> Void)
    func addViewChangedListener(completion: @escaping (_ error: NSError?) -> Void)
    func showThreadList(completion: @escaping (_ error: NSError?) -> Void)
}

@objc public enum MMChatMultiThreadStrategy: Int
{
    case ACTIVE = 0,
         ALL
    
    var stringValue: String {
        switch self {
        case .ACTIVE:
            return "ACTIVE"
        case .ALL:
            return "ALL"
        }
    }
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
    
    func setLanguage(_ language: MMLanguage? = nil) {
        let mmLanguage = language ?? MMLanguage.chatLanguage // If never saved, it is MobileMessaging installation language (or English as default)
        MMLanguage.chatLanguage = mmLanguage
        guard let localeEscaped = mmLanguage.locale.javaScriptEscapedString() else {
            self.logDebug("setLanguage not called, unable to obtain escaped localed for \(mmLanguage.locale)")
            return
        }
        self.evaluateJavaScript("setLanguage(\(localeEscaped))") {
            (response, error) in
            self.logDebug("setLanguage call got a response:\(response.debugDescription), error: \(error?.localizedDescription ?? "")")
        }
    }
    
    func sendContextualData(_ metadata: String, multiThreadStrategy: MMChatMultiThreadStrategy = .ACTIVE,
                            completion: @escaping (_ error: NSError?) -> Void) {
        self.evaluateJavaScript("sendContextualData(\(metadata), '\(multiThreadStrategy.stringValue)')") {
            (response, error) in
            self.logDebug("sendContextualData call got a response:\(response.debugDescription), error: \(error?.localizedDescription ?? "")")
            completion(error as? NSError)
        }
    }
    
    // This function adds a listener to onViewChanged within the web content, informing of the status navigation if multithread is in use.
    // When a change ocurrs, it will be handled by webViewDelegate's didChangeView
    func addViewChangedListener(completion: @escaping (NSError?) -> Void) {
        self.evaluateJavaScript("onViewChanged()") { [weak self] (response, error) in
                self?.logDebug("addViewChangedListener got response:\(response.debugDescription), error: \(error?.localizedDescription ?? "")")
                completion(error as? NSError)
        }
    }
    
    // This functions request a navigation from a thread chat to the thread list (possible if multithead is enabled)
    func showThreadList(completion: @escaping (NSError?) -> Void) {
        self.evaluateJavaScript("showThreadList()") { [weak self] (response, error) in
                self?.logDebug("showThreadList got response:\(response.debugDescription), error: \(error?.localizedDescription ?? "")")
                completion(error as? NSError)
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
