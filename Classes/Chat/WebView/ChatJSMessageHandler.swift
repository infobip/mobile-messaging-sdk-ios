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
    case onMessageEvent
    
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
        case .onMessageEvent:
            return OnMessageEventHandler.self
		}
	}
}

// MARK: Script handlers
class ChatScriptMessageHandler: NSObject, WKScriptMessageHandler {
    
    var onChatEvent: ((JSMessageType, JSMessage) -> Void)?
        
	public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
		guard let jsMessage = JSMessageType(rawValue: message.name) else {
			return
		}
        jsMessage.handler?.handleMessage(message: message, completion: { [weak self] type, message in
            self?.onChatEvent?(type, message)
        })
	}
}

protocol ScriptMessageHandler {
    static func handleMessage(message: WKScriptMessage, completion: @escaping ((JSMessageType, JSMessage) -> Void))
}

class EnableControlsMessageHandler: ScriptMessageHandler {

    class func handleMessage(message: WKScriptMessage, completion: @escaping ((JSMessageType, any JSMessage) -> Void)) {
		guard let jsMessage = EnableControlsJSMessage(message: message) else {
				return
		}
        
        completion(.enableControls, jsMessage)
	}
}

class ErrorMessageHandler: ScriptMessageHandler, NamedLogger {
	class func handleMessage(message: WKScriptMessage, completion: @escaping ((JSMessageType, any JSMessage) -> Void)) {
		guard let jsMessage = ErrorJSMessage(message: message) else {
				return
		}
        
		logError("JSError received: \(jsMessage.message)")
        completion(.onError, jsMessage)
	}
}

class AttachmentPreviewMessageHandler: ScriptMessageHandler {
    class func handleMessage(message: WKScriptMessage, completion: @escaping ((JSMessageType, any JSMessage) -> Void)) {
        guard let jsMessage = AttachmentPreviewJSMessage(message: message) else {
            return
        }

        completion(.openAttachmentPreview, jsMessage)
    }
}

class ControlsVisibilityHandler: ScriptMessageHandler {
    class func handleMessage(message: WKScriptMessage, completion: @escaping ((JSMessageType, JSMessage) -> Void)) {
        guard let jsMessage = VisibilityControlsJSMessage(message: message) else {
                return
        }
        
        completion(.setControlsVisibility, jsMessage)
    }
}

class OnViewChangedHandler: ScriptMessageHandler, NamedLogger {
    class func handleMessage(message: WKScriptMessage, completion: @escaping ((JSMessageType, JSMessage) -> Void)) {
        guard let jsMessage = ViewStateJSMessage(message: message) else {
            return
        }
        
        completion(.onViewChanged, jsMessage)
    }
}


class OnMessageEventHandler: ScriptMessageHandler, NamedLogger {
    class func handleMessage(message: WKScriptMessage, completion: @escaping ((JSMessageType, JSMessage) -> Void)) {
        guard let jsMessage = OnMessageReceivedJSMessage(message: message) else {
            return
        }

        completion(.onMessageEvent, jsMessage)
    }
}

// MARK: JS handlers
protocol JSMessage {
	init?(message: WKScriptMessage)
}

class ErrorJSMessage: JSMessage, NamedLogger {
	let message: String
    let additionalInfo: String?

	required init?(message: WKScriptMessage) {
		guard let bodyDict = message.body as? [String: AnyObject] else {
				ErrorJSMessage.logError("Error while handling js error message, data wasn't provided")
				return nil
		}

        self.message = (bodyDict[ChatAPIKeys.JSMessageKeys.errorMessage] as? String) ?? "Wrong InAppchat setup or method invocation"
        self.additionalInfo = bodyDict[ChatAPIKeys.JSMessageKeys.additionalInfo] as? String
	}
}

class EnableControlsJSMessage: JSMessage, NamedLogger {
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

class VisibilityControlsJSMessage: JSMessage, NamedLogger {
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

class ViewStateJSMessage: JSMessage, NamedLogger {
    let state: MMChatWebViewState
    
    required init?(message: WKScriptMessage) {
        let viewState = (message.body as? String) ?? "Unknown view state"
        self.state = MMChatWebViewState.parseFrom(viewState)
        logDebug("OnViewChangedHandler handleMessage \(viewState)")
    }
}

class OnMessageReceivedJSMessage: JSMessage, NamedLogger {
    var message: Any
    
    required init?(message: WKScriptMessage) {
        self.message = message.body
    }
}
