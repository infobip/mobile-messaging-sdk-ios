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
			isOpaque = true
			scrollView.backgroundColor = UIColor(hexString: backgroundColor)
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
		
		guard let componentsUrl = components.url else {
			logDebug("can't load ChatConnector.html, components.url = nil")
			return nil
		}
		return URLRequest(url: componentsUrl)
	}
}
