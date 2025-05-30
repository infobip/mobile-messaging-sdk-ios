//
//  AsyncJSExecutor.swift
//  MobileMessaging
//
//  Created by Maksym Svitlovskyi on 13/03/2025.
//

import WebKit

extension WKWebView {
    private struct AsyncJSCallbackInfo {
        let completion: (Swift.Result<Any, Error>) -> Void
    }
    private static var asyncCallbacksKey = "com.wkwebview.asyncJSCallbacks"
    private static var bridgeSetupKey = "com.wkwebview.bridgeSetup"

    private func associatedObject<T>(key: UnsafeRawPointer, defaultValue: @autoclosure () -> T) -> T {
        if let value = objc_getAssociatedObject(self, key) as? T {
            return value
        }
        let defaultValue = defaultValue()
        objc_setAssociatedObject(self, key, defaultValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return defaultValue
    }

    private func setAssociatedObject<T>(key: UnsafeRawPointer, value: T) {
        objc_setAssociatedObject(self, key, value, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private var asyncCallbacks: [String: AsyncJSCallbackInfo] {
        get {
            return withUnsafePointer(to: &Self.asyncCallbacksKey) {
                return associatedObject(key: $0, defaultValue: [:])
            }
        }
        set {
            withUnsafePointer(to: &Self.asyncCallbacksKey) {
                setAssociatedObject(key: $0, value: newValue)
            }
        }
    }

    private var isBridgeSetup: Bool {
        get {
            return withUnsafePointer(to: &Self.bridgeSetupKey) {
                return associatedObject(key: $0, defaultValue: false)
            }
        }
        set {
            withUnsafePointer(to: &Self.bridgeSetupKey) {
                setAssociatedObject(key: $0, value: newValue)
            }
        }
    }

    private func setupAsyncBridgeIfNeeded() {
        if isBridgeSetup {
            return
        }
        
        let handler = AsyncJSBridgeHandler(webView: self)
        self.configuration.userContentController.add(handler, name: "asyncJSBridge")
        isBridgeSetup = true
    }
    
    /// Evaluates asynchronous JavaScript and returns the result via completion handler
    public func evaluateAsyncInMainThread(_ javaScript: String, completion: @escaping (Swift.Result<Any, Error>) -> Void) {
#if targetEnvironment(simulator)
        // callAsyncJavaScript started crashing in simulator on Xcode 16.4 for unknown reasons
#else
        if #available(iOS 14.0, *) {
            DispatchQueue.mmEnsureMain{ [weak self] in
                self?.callAsyncJavaScript(
                    javaScript,
                    in: nil,
                    in: .page
                ) { result in
                    completion(result)
                }
            }
            return
        }
#endif

        setupAsyncBridgeIfNeeded()
        
        let callbackID = UUID().uuidString
        
        var callbacks = self.asyncCallbacks
        callbacks[callbackID] = AsyncJSCallbackInfo(completion: completion)
        self.asyncCallbacks = callbacks
        
        let jsWrapper = """
        (function() {
            const callbackID = "\(callbackID)";

            async function executeAsyncCode() {
                try {
                    const result = await (async function() { \(javaScript) })();
                    window.webkit.messageHandlers.asyncJSBridge.postMessage({
                        id: callbackID,
                        status: "success",
                        result: result
                    });
                } catch (error) {
                    window.webkit.messageHandlers.asyncJSBridge.postMessage({
                        id: callbackID,
                        status: "error",
                        error: error instanceof Error ? error.message : String(error)
                    });
                }
            }

            executeAsyncCode();
        })();
        """

        self.evaluateInMainThread(jsWrapper) { (_, error) in
            if let error = error {
                var callbacks = self.asyncCallbacks
                callbacks.removeValue(forKey: callbackID)
                self.asyncCallbacks = callbacks

                completion(.failure(error))
            }
        }
    }
    
    fileprivate func processAsyncJavaScriptMessage(_ message: WKScriptMessage) {
        guard message.name == "asyncJSBridge",
              let body = message.body as? [String: Any],
              let callbackID = body["id"] as? String else {
            return
        }
        
        var callbacks = self.asyncCallbacks
        guard let callbackInfo = callbacks[callbackID] else {
            return
        }
        callbacks.removeValue(forKey: callbackID)
        self.asyncCallbacks = callbacks
        
        if let status = body["status"] as? String {
            if status == "success" {
                callbackInfo.completion(.success(body["result"] ?? NSNull()))
            } else {
                let errorMessage = body["error"] as? String ?? "Unknown error"
                let error = NSError(domain: "AsyncJSError",
                                   code: -1,
                                   userInfo: [NSLocalizedDescriptionKey: errorMessage])
                callbackInfo.completion(.failure(error))
            }
        }
    }
}

private class AsyncJSBridgeHandler: NSObject, WKScriptMessageHandler {
    private weak var webView: WKWebView?
    
    init(webView: WKWebView) {
        self.webView = webView
        super.init()
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let webView = self.webView else { return }
        webView.processAsyncJavaScriptMessage(message)
    }
}
