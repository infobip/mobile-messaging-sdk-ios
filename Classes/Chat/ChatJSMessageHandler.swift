//
//  ChatJSHandler.swift
//  MobileMessaging
//
//  Created by okoroleva on 24.04.2020.
//

import Foundation
import WebKit

//supported js message types
enum JSMessageType: String, CaseIterable {
	case enableControls
	case onError
	var handler: ScriptMessageHandler.Type? {
		switch self {
		case .enableControls:
			return EnableControlsMessageHandler.self
		case .onError:
			return ErrorMessageHandler.self
		}
	}
}

class ChatScriptMessageHandler: NSObject, WKScriptMessageHandler {
	public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
		guard let jsMessage = JSMessageType(rawValue: message.name) else {
			return
		}
		jsMessage.handler?.handleMessage(message: message)
	}
}

protocol ScriptMessageHandler {
	static func handleMessage(message: WKScriptMessage)
}

class EnableControlsMessageHandler: ScriptMessageHandler {
	class func handleMessage(message: WKScriptMessage) {
		guard let jsMessage = EnableControlsJSMessage(message: message) else {
				return
		}
		MobileMessaging.inAppChat?.webViewDelegate?.enableControls(jsMessage.enabled)
	}
}

class ErrorMessageHandler: ScriptMessageHandler {
	class func handleMessage(message: WKScriptMessage) {
		guard let jsMessage = ErrorJSMessage(message: message) else {
				return
		}
		MMLogError("[InAppChat] JSError received: \(jsMessage.message)")
	}
}

protocol JSMessage {
	init?(message: WKScriptMessage)
}

class ErrorJSMessage : JSMessage {
	let message: String
	
	required init?(message: WKScriptMessage) {
		guard let bodyDict = message.body as? [String: AnyObject],
			let errorMessage = bodyDict[ChatAPIKeys.JSMessageKeys.errorMessage] as? String else {
				MMLogDebug("[InAppChat] Error while handling js error message, data wasn't provided")
				return nil
		}
		self.message = errorMessage
	}
}

class EnableControlsJSMessage : JSMessage {
	let enabled: Bool
	
	required init?(message: WKScriptMessage) {
		guard let bodyDict = message.body as? [String: AnyObject],
			let enabled = bodyDict[ChatAPIKeys.JSMessageKeys.enabled] as? Bool else {
				MMLogDebug("[InAppChat] Error while handling js enableControls message, data wasn't provided")
				return nil
		}
		self.enabled = enabled
	}
}
