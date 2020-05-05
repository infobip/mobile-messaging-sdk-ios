//
//  CPWebViewChatViewController.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 14.04.2020.
//

import WebKit

protocol ChatWebViewDelegate {
	func loadWidget(_ widget: ChatWidget)
	func enableControls(_ enabled: Bool)
}

open class CPChatViewController: CPMessageComposingViewController, ChatWebViewDelegate, ChatSettingsApplicable {

	public static func makeRootNavigationViewController() -> CPChatNavigationVC {
		return CPChatNavigationVC.makeWebViewChatNavigationViewController()
	}

	public static func makeChildNavigationViewController() -> CPChatViewController {
		return CPChatViewController(type: .back)
	}
	
	public static func makeModalViewController() -> CPChatViewController {
		return CPChatViewController(type: .dismiss)
	}
	
	var webView: ChatWebView!

	override var scrollView: UIScrollView! {
		return webView.scrollView
	}

	override var scrollViewContainer: UIView! {
		return webView
	}

	open override func loadView() {
		super.loadView()
		setupWebView()
	}

	open override func viewDidLoad() {
		super.viewDidLoad()
		MobileMessaging.inAppChat?.webViewDelegate = self
		enableControls(false)
		registerToChatSettingsChanges()

		if #available(iOS 13, *) {
			webView.backgroundColor = UIColor.systemBackground
			view.backgroundColor = UIColor.systemBackground
		} else {
			webView.backgroundColor = UIColor.white
			view.backgroundColor = UIColor.white
		}
    }
	
	open override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		MobileMessaging.inAppChat?.isChatScreenVisible = true
	}
	
	open override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		MobileMessaging.inAppChat?.isChatScreenVisible = false
	}

	override func didTapSendText(_ text: String) {
		webView.sendMessage(text)
	}
	
	//ChatSettingsApplicable
	func applySettings() {
        guard let settings = MobileMessaging.inAppChat?.settings else {
            return
        }
		
		if let navBarColor = settings.navBarColor {
			navigationController?.navigationBar.barTintColor = navBarColor
		}
		
		if let navBarItemsTintColor = settings.navBarItemsTintColor {
			navigationController?.navigationBar.tintColor = navBarItemsTintColor
		}
		navigationController?.navigationBar.isTranslucent = false
		if let navBarTitleColor = settings.navBarTitleColor {
			navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : navBarTitleColor]
		}
		title = settings.title
		
		if let sendButtonTintColor = settings.sendButtonTintColor {
			composeBarView.buttonTintColor = sendButtonTintColor
		}
	}
	
	// ChatWebViewDelegate
	func loadWidget(_ widget: ChatWidget) {
		webView.loadWidget(widget)
	}
	
	func enableControls(_ enabled: Bool) {
		webView.isUserInteractionEnabled = enabled
		composeBarView.isEnabled = enabled
	}
	
	// Private
	private func setupWebView() {
		webView = ChatWebView(frame: view.bounds)
		webView.navigationDelegate = self
		webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(webView)
	}

}

extension CPChatViewController: WKNavigationDelegate {
	public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		guard navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url, UIApplication.shared.canOpenURL(url) else {
			decisionHandler(.allow)
			return
		}
		MMLogDebug("[InAppChat] will open URL: \(url)")
		UIApplication.shared.open(url)
		decisionHandler(.cancel)
	}
}
