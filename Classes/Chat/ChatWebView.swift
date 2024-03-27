//
//  ChatWebView.swift
//  MobileMessaging
//
//  Created by okoroleva on 29.04.2020.
//

import Foundation
import WebKit

class ChatWebView: WKWebView {
	let scriptHandler = ChatScriptMessageHandler()
    var isLoaded = false
    
	deinit {
		self.stopLoading()
		for value in JSMessageType.allCases {
			self.configuration.userContentController.removeScriptMessageHandler(forName: value.rawValue)
		}
	}
	
	init(frame: CGRect) {
		let configuration = WKWebViewConfiguration()
		for value in JSMessageType.allCases {
			configuration.userContentController.add(scriptHandler, name: value.rawValue)
		}
		super.init(frame: frame, configuration: configuration)
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}
	
	func loadWidget(_ widget: ChatWidget) {
		guard let pushRegistrationId = MobileMessaging.sharedInstance?.currentInstallation().pushRegistrationId,
			let request = request(forWidgetId: widget.widgetId, pushRegId: pushRegistrationId) else {
				logDebug("no push registration id, can't start chat")
				return
		}
		if let backgroundColor = widget.backgroundColor {
            DispatchQueue.mmEnsureMain { [weak self] in
                self?.isOpaque = true
                self?.scrollView.backgroundColor = UIColor(hexString: backgroundColor)
            }
		}
		load(request)
	}
	
	private func request(forWidgetId widgetId: String, pushRegId: String) -> URLRequest? {
		logDebug("pushregId: \(pushRegId) widgetId: \(widgetId)")
		
		guard let url = MMInAppChatService.resourceBundle.url(forResource: "ChatConnector", withExtension: "html"),
		      loadFileURL(url, allowingReadAccessTo: url) != nil,
		      var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
				logDebug("can't load ChatConnector.html")
			return nil
		}
		components.queryItems = [
			URLQueryItem(name: ChatAPIKeys.QueryParams.pushRegId, value: pushRegId),
			URLQueryItem(name: ChatAPIKeys.QueryParams.widgetId, value: widgetId),
		]
        if let jwt = MobileMessaging.inAppChat?.jwt {
            components.queryItems?.append(URLQueryItem(name: ChatAPIKeys.QueryParams.jwt, value: jwt))
        }
        if let theme = MMChatSettings.settings.widgetTheme {
            components.queryItems?.append(URLQueryItem(name: ChatAPIKeys.QueryParams.theme, value: theme))
        }

		guard let componentsUrl = components.url else {
			logDebug("can't load ChatConnector.html, components.url = nil")
			return nil
		}
		return URLRequest(url: componentsUrl)
	}
}

@objc public enum MMChatWebViewState: Int {
    case loading = 0, threadList, loadingThread, thread, singleThreadMode, closedThread, unknown
    static func parseFrom(_ value: String) -> MMChatWebViewState {
        switch value {
        case "LOADING": // Loading spinner while initial view is being requested or rendered
            return .loading
        case "THREAD_LIST": // In a multi-thread widget, this represents a list with opened threads to be selected
            return .threadList
        case "LOADING_THREAD": // Loading state when opening new thread or existing thread
            return .loadingThread
        case "THREAD": // View for currently opened thread in multi-thread widget
            return .thread
        case "SINGLE_MODE_THREAD": // Single-thread widget, indicating multithread is disabled
            return .singleThreadMode
        case "CLOSED_THREAD":
            return .closedThread
        default:
            return .unknown // Something went wrong or your SDK is not up to date
        }
    }
}
