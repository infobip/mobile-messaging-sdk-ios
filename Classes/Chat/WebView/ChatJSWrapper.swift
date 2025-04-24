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
    func sendMessage(_ message: String?, attachment: ChatMobileAttachment?,
                     completion: @escaping (_ error: NSError?) -> Void)
    func sendDraft(_ message: String?,
                   completion: @escaping (_ error: NSError?) -> Void)
    func setLanguage(_ language: MMLanguage?,
                     completion: @escaping (_ error: NSError?) -> Void)
    func sendContextualData(_ metadata: String, multiThreadStrategy: MMChatMultiThreadStrategy,
                            completion: @escaping (_ error: NSError?) -> Void)
    func addViewChangedListener(completion: @escaping (_ error: NSError?) -> Void)
    func showThreadsList(completion: @escaping (_ error: NSError?) -> Void)
    func setTheme(_ themeName: String,
                 completion: @escaping (_ error: NSError?) -> Void)
}

@objc public enum MMChatMultiThreadStrategy: Int
{
    case ACTIVE = 0,
         ALL,
         ALL_PLUS_NEW
    
    var stringValue: String {
        switch self {
        case .ACTIVE:
            return "ACTIVE"
        case .ALL:
            return "ALL"
        case .ALL_PLUS_NEW:
            return "ALL_PLUS_NEW"
        }
    }
}

extension WKWebView: NamedLogger {}

extension WKWebView: ChatJSWrapper {

    func evaluateInMainThread(_ javaScriptString: String, completionHandler: (@MainActor @Sendable (Any?, (any Error)?) -> Void)? = nil) {
        DispatchQueue.mmEnsureMain() {
            self.evaluateJavaScript(javaScriptString) { (response, error) in
                completionHandler?(response, error)
            }
        }
    }

    func sendMessage(_ message: String? = nil, attachment: ChatMobileAttachment? = nil) {
        sendMessage(message, attachment: attachment, completion: { _ in })
    }
    
    func sendMessage(_ message: String? = nil, attachment: ChatMobileAttachment? = nil, completion: @escaping (NSError?) -> Void) {
        let escapedMessage = message?.javaScriptEscapedString()
        guard escapedMessage != nil || attachment != nil else {
            let reasonString = "sendMessage failed, neither message nor the attachment provided"
			logDebug(reasonString)
            completion(NSError(code: .conditionFailed, userInfo: ["reason" : reasonString]))
			return
		}
        self.evaluateInMainThread(
            "sendMessage(\(escapedMessage ?? "''"), '\(attachment?.base64UrlString() ?? "")', '\(attachment?.fileName ?? "")')")
        { [weak self] (response, error) in
			self?.logDebug("sendMessage call got a response: \(response.debugDescription), error: \(error?.localizedDescription ?? "")")
            completion(error as? NSError)
		}
	}

    func sendDraft(_ message: String?) {
        sendDraft(message, completion: { _ in })
    }
    
    func sendDraft(_ message: String?, completion: @escaping (_ error: NSError?) -> Void) {
        let escapedMessage = message?.javaScriptEscapedString()
        guard escapedMessage != nil else {
            let reasonString = "sendDraft failed, message not provided"
            logDebug(reasonString)
            completion(NSError(code: .conditionFailed, userInfo: ["reason" : reasonString]))
            return
        }
        
        self.evaluateInMainThread("sendDraft(\(escapedMessage ?? ""))"){
            (response, error) in
            self.logDebug("sendDraft call got a response:\(response.debugDescription), error: \(error?.localizedDescription ?? "")")
            completion(error as? NSError)
        }
    }
   
    func setLanguage(_ language: MMLanguage? = nil) {
        setLanguage(language, completion: { _ in })
    }
        
    func setLanguage(_ language: MMLanguage? = nil, completion: @escaping (_ error: NSError?) -> Void) {
        let mmLanguage = language ?? MMLanguage.sessionLanguage // If never saved, it is MobileMessaging installation language (or English as default)
        MMLanguage.sessionLanguage = mmLanguage
        guard let localeEscaped = mmLanguage.locale.javaScriptEscapedString() else {
            let reasonString = "setLanguage not called, unable to obtain escaped localed for \(mmLanguage.locale)"
            logDebug(reasonString)
            completion(NSError(code: .conditionFailed, userInfo: ["reason" : reasonString]))
            return
        }
        self.evaluateInMainThread("setLanguage(\(localeEscaped))") {
            (response, error) in
            self.logDebug("setLanguage call got a response:\(response.debugDescription), error: \(error?.localizedDescription ?? "")")
            completion(error as? NSError)
        }
    }
    
    func sendContextualData(_ metadata: String, multiThreadStrategy: MMChatMultiThreadStrategy = .ACTIVE,
                            completion: @escaping (_ error: NSError?) -> Void) {
        self.evaluateInMainThread("sendContextualData(\(metadata), '\(multiThreadStrategy.stringValue)')") {
            (response, error) in
            self.logDebug("sendContextualData call got a response:\(response.debugDescription), error: \(error?.localizedDescription ?? "")")
            completion(error as? NSError)
        }
    }
    
    // This function adds a listener to onViewChanged within the web content, informing of the status navigation if multithread is in use.
    // When a change ocurrs, it will be handled by webViewDelegate's didChangeView
    func addViewChangedListener(completion: @escaping (NSError?) -> Void) {
        self.evaluateInMainThread("onViewChanged()") { [weak self] (response, error) in
                self?.logDebug("addViewChangedListener got response:\(response.debugDescription), error: \(error?.localizedDescription ?? "")")
                completion(error as? NSError)
        }
    }
    
    func addMessageReceivedListener(completion: @escaping (NSError?) -> Void) {
        self.evaluateInMainThread("onMessageReceived()") { [weak self] (response, error) in
            self?.logDebug("addMessageReceivedListener got response:\(response.debugDescription), error: \(error?.localizedDescription ?? "")")
            completion(error as? NSError)
        }
    }
    
    // This functions request a navigation from a thread chat to the thread list (possible if multithead is enabled)
    func showThreadsList(completion: @escaping (NSError?) -> Void) {
        self.evaluateInMainThread("showThreadsList()") { [weak self] (response, error) in
            self?.logDebug("showThreadsList got response:\(response.debugDescription), error: \(error?.localizedDescription ?? "")")
            completion(error as? NSError)
        }
    }

    // This functions pauses the chat, effectively closing its socket. As result, the connection will be considered as ended, and
    // remote push notifications will start coming to the device. This is useful for example when app is going to background/becoming inactive
    func pauseChat(completion: @escaping (NSError?) -> Void) {
        self.evaluateInMainThread("pauseChat()") { [weak self] (response, error) in
            self?.logDebug("pauseChat got response:\(response.debugDescription), error: \(error?.localizedDescription ?? "")")
            completion(error as? NSError)
        }
    }

    // This functions resumes the chat, effectively reopening its socket. As result, the connection will be reestablished, and
    // remote push notifications will stop coming to the device. This is useful for example when app is going to foreground/becoming active
    func resumeChat(completion: @escaping (NSError?) -> Void) {
        self.evaluateInMainThread("resumeChat()") { [weak self] (response, error) in
            self?.logDebug("resumeChat got response:\(response.debugDescription), error: \(error?.localizedDescription ?? "")")
            completion(error as? NSError)
        }
    }

    func setTheme(_ themeName: String, completion: @escaping (_ error: NSError?) -> Void) {
        guard let themeJS = themeName.javaScriptEscapedString() else {
            let reasonString = "setTheme not called, unable to obtain escaped localed for \(themeName)"
            logDebug(reasonString)
            completion(NSError(code: .conditionFailed, userInfo: ["reason" : reasonString]))
            return
        }
        self.evaluateInMainThread("setTheme(\(themeJS))") {
            (response, error) in
            self.logDebug("setTheme call got a response:\(response.debugDescription), error: \(error?.localizedDescription ?? "")")
            completion(error as? NSError)
        }
    }
    
    func getThreads(completion: @escaping (Swift.Result<[MMLiveChatThread], Error>) -> Void) {

        struct Response: Codable {
            let data: [MMLiveChatThread]
        }

        self.evaluateAsyncInMainThread(
        """
        const res = await getLivechatSdk().getThreads();
        return res
        """, /// We should `return` at least something, native callAsyncJavaScript accept same format
        completion: {  [weak self] result in
            switch result {
            case .success(let value):
                guard let data = try? JSONSerialization.data(withJSONObject: value),
                      let result = try? JSONDecoder().decode(Response.self, from: data) else {
                    
                    let reasonString = "getThreads failed, unable to parse value: \(value)"
                    self?.logDebug(reasonString)
                    completion(.failure(NSError(code: .conditionFailed, userInfo: ["reason" : reasonString])))
                    
                    return
                }
                completion(.success(result.data))
            case .failure(let error):
                completion(.failure(error))
            }
        })
    }
    
    func getActiveThread(completion: @escaping (Swift.Result<MMLiveChatThread?, any Error>) -> Void) {

        struct Response: Codable {
            let data: MMLiveChatThread
        }

        self.evaluateAsyncInMainThread(
        """
        const res = await getLivechatSdk().getActiveThread();
        return res
        """, /// We should `return` at least something, native callAsyncJavaScript accept same format
        completion: { result in
            switch result {
            case .success(let value):
                guard let data = try? JSONSerialization.data(withJSONObject: value),
                      let result = try? JSONDecoder().decode(Response.self, from: data) else {
                    return completion(.success(nil))
                }
                completion(.success(result.data))
            case .failure(let error):
                completion(.failure(error))
            }
        })
    }

    func openThread(threadId: String, completion: @escaping (Swift.Result<MMLiveChatThread, any Error>) -> Void) {
        
        struct Response: Codable {
            let data: MMLiveChatThread
        }

        guard let id = threadId.javaScriptEscapedString() else {
            
            let reasonString = "openThread failed, invalid threadId: \(threadId)"
            self.logDebug(reasonString)
            completion(.failure(NSError(code: .conditionFailed, userInfo: ["reason" : reasonString])))
            
            return
        }

        self.evaluateAsyncInMainThread(
        """
        const res = await getLivechatSdk().getWidget().showThread(\(id));
        return res
        """, /// We should `return` at least something, native callAsyncJavaScript accept same format
        completion: { [weak self] result in
            switch result {
            case .success(let value):
                guard let data = try? JSONSerialization.data(withJSONObject: value),
                      let result = try? JSONDecoder().decode(Response.self, from: data) else {
                    let reasonString = "openThread failed, unable to parse value: \(value)"
                    self?.logDebug(reasonString)
                    completion(.failure(NSError(code: .conditionFailed, userInfo: ["reason" : reasonString])))

                    return
                }
                completion(.success(result.data))
            case .failure(let error):
                completion(.failure(error))
            }
        })
    }
}

extension String {
    func javaScriptEscapedString() -> String? {
        let data = try! JSONSerialization.data(withJSONObject:[self], options: [])
		if let encodedString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
			return encodedString.substring(with: NSMakeRange(1, encodedString.length - 2))
		}
        return nil
    }
}

