// 
//  ChatJSWrapper.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import WebKit

protocol ChatJSWrapper {
    func send(_ payload: MMLivechatPayload, _ completion: @escaping (_ error: NSError?) -> Void)
    func setLanguage(_ language: MMLanguage?)
    func setLanguage(_ language: MMLanguage?,
                     completion: @escaping (_ error: NSError?) -> Void)
    func sendContextualData(_ metadata: String, multiThreadStrategy: MMChatMultiThreadStrategy,
                            completion: @escaping (_ error: NSError?) -> Void)
    func addViewChangedListener(completion: @escaping (_ error: NSError?) -> Void)
    func showThreadsList(completion: @escaping (_ error: NSError?) -> Void)
    func setTheme(_ themeName: String, completion: @escaping (_ error: NSError?) -> Void)
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

extension WKWebView: @retroactive NamedLogger {}

extension WKWebView: ChatJSWrapper {
    func evaluateInMainThread(_ javaScriptString: String, completionHandler: (@MainActor @Sendable (Any?, (any Error)?) -> Void)? = nil) {
        DispatchQueue.mmEnsureMain() {
            self.evaluateJavaScript(javaScriptString) { (response, error) in
                completionHandler?(response, error)
            }
        }
    }

    private func validate(_ response: MMLivechatMessageResponse?, payload: MMLivechatPayload, error: (any Error)? = nil) -> NSError? {
        self.logDebug(String(
            format: payload.type.errorString,
            response.debugDescription,
            error?.localizedDescription ?? ""))
        guard let response = response else {
            return error as? NSError
        }
        guard let lcError = response.error, !response.success else {
            return nil
        }

        return NSError(
            code: .conditionFailed,
             userInfo: ["reason" : lcError.description, "payload": payload.interfaceValue])
    }

    private func handleCompletion(
        payload: MMLivechatPayload,
        response: MMLivechatMessageResponse? = nil,
        error: (any Error)? = nil,
        completion: @escaping (_ error: NSError?) -> Void) {
        let validationError = validate(response, payload: payload, error: error)
        completion(validationError)
    }

    private func handleCompletion(
        payload: MMLivechatPayload,
        response: MMLivechatMessageResponse? = nil,
        error: (any Error)? = nil,
        completion: (_ thread: MMLiveChatThread?, _ error: NSError?) -> Void) {
        let validationError = validate(response, payload: payload, error: error)
        completion(nil, validationError)
    }

    func send(
        _ payload: MMLivechatPayload,
        _ completion: @escaping (_ error: NSError?) -> Void) {
        let contentString = payload.interfaceValue
        let javascriptCode =  """
        const res = await getLivechatSdk().sendMessage(\(contentString));
        return res;
        """ // We should `return` at least something, native callAsyncJavaScript accept same format
        self.evaluateAsyncInMainThread(
        javascriptCode,
        completion: { [weak self] result in
            switch result {
            case .success(let value):
                guard let data = try? JSONSerialization.data(withJSONObject: value),
                      let response = try? JSONDecoder().decode(MMLivechatMessageResponse.self, from: data) else {
                    let reasonString = "sendMessage failed, unable to parse value: \(value)"
                    let error = NSError(code: .conditionFailed,
                                        userInfo: ["reason" : reasonString,
                                                   "payload": payload.interfaceValue])
                    self?.handleCompletion(payload: payload, error: error, completion: completion)
                    return
                }
                self?.handleCompletion(payload: payload, response: response, completion: completion)
            case .failure(let error):
                self?.handleCompletion(payload: payload, error: error, completion: completion)
            }
        })
    }

    func createThread(
        _ payload: MMLivechatPayload,
        _ completion: @escaping (_ thread: MMLiveChatThread?, _ error: NSError?) -> Void) {
        let contentString = payload.interfaceValue
        let javascriptCode =  """
        const res = await getLivechatSdk().createThread(\(contentString));
        return res;
        """ // We should `return` at least something, native callAsyncJavaScript accept same format
        self.evaluateAsyncInMainThread(
        javascriptCode,
        completion: {  [weak self] result in
            switch result {
            case .success(let value):
                guard let data = try? JSONSerialization.data(withJSONObject: value),
                      let response = try? JSONDecoder().decode(MMLivechatMessageResponse.self, from: data) else {
                    let reasonString = "createThread failed, unable to parse value: \(value)"
                    let error = NSError(code: .conditionFailed, userInfo: ["reason" : reasonString])
                    self?.handleCompletion(payload: payload, error: error, completion: completion)
                    return
                }
                guard response.success else {
                    self?.handleCompletion(payload: payload, response: response, completion: completion)
                    return
                }
                completion(response.data?.thread, nil)
            case .failure(let error):
                self?.handleCompletion(payload: payload, error: error, completion: completion)
            }
        })
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

    func openNewThread(completion: @escaping (NSError?) -> Void) {
        self.evaluateInMainThread("openNewThread()") { [weak self] (response, error) in
            self?.logDebug("openNewThread got response:\(response.debugDescription), error: \(error?.localizedDescription ?? "")")
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
                    completion(.success(nil))
                    return
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

