//
//  ChatJSHandler.swift
//  MobileMessaging
//
//  Created by okoroleva on 24.04.2020.
//

import Foundation
import WebKit

// MARK: Supported JS message types
enum JSMessageType: String, CaseIterable {
	case enableControls
	case onError
    case openAttachmentPreview
    case setControlsVisibility
    case onViewChanged
	var handler: ScriptMessageHandler.Type? {
		switch self {
		case .enableControls:
			return EnableControlsMessageHandler.self
		case .onError:
			return ErrorMessageHandler.self
        case .openAttachmentPreview:
            return AttachmentPreviewMessageHandler.self
        case .setControlsVisibility:
            return ControlsVisibilityHandler.self
        case .onViewChanged:
            return OnViewChangedHandler.self
		}
	}
}

// MARK: Script handlers
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
		MobileMessaging.inAppChat?.webViewDelegate?.didEnableControls(jsMessage.enabled)
	}
}

class ErrorMessageHandler: ScriptMessageHandler, NamedLogger {
	class func handleMessage(message: WKScriptMessage) {
		guard let jsMessage = ErrorJSMessage(message: message) else {
				return
		}
		logError("JSError received: \(jsMessage.message)")
        MobileMessaging.inAppChat?.handleJSError(jsMessage.message)
	}
}

class AttachmentPreviewMessageHandler: ScriptMessageHandler {
    class func handleMessage(message: WKScriptMessage) {
        guard let jsMessage = AttachmentPreviewJSMessage(message: message) else {
            return
        }
        guard let attachment = ChatWebAttachment(url: jsMessage.url, typeString: jsMessage.type, fileName: jsMessage.caption) else {
            return
        }
        
        MobileMessaging.inAppChat?.webViewDelegate?.didOpenPreview(forAttachment: attachment)
    }
}

class ControlsVisibilityHandler: ScriptMessageHandler {
    class func handleMessage(message: WKScriptMessage) {
        guard let jsMessage = VisibilityControlsJSMessage(message: message) else {
                return
        }
        MobileMessaging.inAppChat?.webViewDelegate?.didShowComposeBar(jsMessage.isVisible)
    }
}

class OnViewChangedHandler: ScriptMessageHandler, NamedLogger {
    class func handleMessage(message: WKScriptMessage) {
        let viewState = (message.body as? String) ?? "Unknown view state"
        logDebug("OnViewChangedHandler handleMessage \(viewState)")
        MobileMessaging.inAppChat?.webViewDelegate?.didChangeView(MMChatWebViewState.parseFrom(viewState))
        UserEventsManager.postInAppChatViewChangedEvent(viewState)
    }
}

// MARK: JS handlers
protocol JSMessage {
	init?(message: WKScriptMessage)
}

class ErrorJSMessage : JSMessage, NamedLogger {
	let message: String
	
	required init?(message: WKScriptMessage) {
		guard let bodyDict = message.body as? [String: AnyObject],
			let errorMessage = bodyDict[ChatAPIKeys.JSMessageKeys.errorMessage] as? String else {
				ErrorJSMessage.logError("Error while handling js error message, data wasn't provided")
				return nil
		}
		self.message = errorMessage
	}
}

class EnableControlsJSMessage : JSMessage, NamedLogger {
	let enabled: Bool
	
	required init?(message: WKScriptMessage) {
		guard let bodyDict = message.body as? [String: AnyObject],
			let enabled = bodyDict[ChatAPIKeys.JSMessageKeys.enabled] as? Bool else {
				ErrorJSMessage.logError("Error while handling js enableControls message, data wasn't provided")
				return nil
		}
		self.enabled = enabled
	}
}

class AttachmentPreviewJSMessage: JSMessage, NamedLogger {
    let url: URL
    let type: String
    let caption: String?
    
    required init?(message: WKScriptMessage) {
        guard let bodyDict = message.body as? [String: AnyObject],
            let urlString = bodyDict[ChatAPIKeys.JSMessageKeys.attachmentUrl] as? String,
            let url = URL(string: urlString),
            let type = bodyDict[ChatAPIKeys.JSMessageKeys.attachmentType] as? String else {
                ErrorJSMessage.logError("Error while handling js openAttachmentPreview message, data wasn't provided")
                return nil
        }
        self.url = url
        self.type = type
        self.caption = (bodyDict[ChatAPIKeys.JSMessageKeys.attachmentCaption] as? String)
    }
}

class VisibilityControlsJSMessage : JSMessage, NamedLogger {
    let isVisible: Bool
    
    required init?(message: WKScriptMessage) {
        guard let bodyDict = message.body as? [String: AnyObject],
            let isVisible = bodyDict[ChatAPIKeys.JSMessageKeys.isVisibleControls] as? Bool else {
                ErrorJSMessage.logError("Error while handling js visibilityControls message, data wasn't provided")
                return nil
        }
        self.isVisible = isVisible
    }
}
