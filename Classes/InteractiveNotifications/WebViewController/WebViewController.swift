//
//  WebViewController.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 29.03.2020.
//

import WebKit

public class WebViewController: UINavigationController {
	init(url: String) {
		super.init(rootViewController: WebViewControllerBase(url: url))
		navigationBar.isTranslucent = false
		if #available(iOS 13.0, *) {
			navigationBar.tintColor = UIColor.label
			navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.label as Any]
		} else {
			navigationBar.tintColor = UIColor.black
			navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.black as Any]
		}
	}

	override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
		super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	public var rootWebViewController: WebViewControllerBase? {
		return viewControllers.first as? WebViewControllerBase
	}

	public var tintColor: UIColor? {
		set { navigationBar.tintColor = newValue }
		get { return navigationBar.tintColor } }

	public var barTintColor: UIColor? {
		set { navigationBar.barTintColor = newValue }
		get { return navigationBar.barTintColor } }

	public var titleColor: UIColor? {
		set { navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : newValue as Any] }
		get { return navigationBar.titleTextAttributes?[NSAttributedString.Key.foregroundColor] as? UIColor } }

	public override var title: String? {
		set { (viewControllers.first as? WebViewControllerBase)?.customTitle = newValue }
		get { return viewControllers.first?.title } }
}


public class WebViewControllerBase: UIViewController, WebViewToolbarDelegate, WKNavigationDelegate {
	let url: String
	var customTitle: String? {
		didSet {
			self.title = customTitle
		}
	}
	lazy var webView: WKWebView = WKWebView()

	deinit {
		webView.removeObserver(self, forKeyPath: "title")
	}

	init(url: String) {
		self.url = url
		super.init(nibName: nil, bundle: nil)

		webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		webView.navigationDelegate = self
		webView.contentMode = .scaleAspectFit
		webView.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height)
		webView.addObserver(self, forKeyPath: "title", options: .new, context: nil)
		if #available(iOS 13, *) {
			view.backgroundColor = UIColor.systemBackground
			webView.scrollView.backgroundColor = UIColor.systemBackground
			webView.backgroundColor = UIColor.systemBackground
		} else {
			view.backgroundColor = UIColor.white
			webView.scrollView.backgroundColor = UIColor.white
			webView.backgroundColor = UIColor.white
		}
		navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(webViewToolbarDidPressDismiss))
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override public func viewDidLoad() {
		super.viewDidLoad()
		view.addSubview(webView)
	}

	public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		if (customTitle == nil && keyPath == "title") {
			self.title = change?[NSKeyValueChangeKey.newKey] as? String
		} else {
			return
		}
	}

	override public func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		reload()
	}

	public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
		enterFailedState()
	}

	public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
		enterFailedState()
	}

	@objc func reload() {
		guard let targetUrl = URL(string: url) else {
			return
		}
		navigationItem.leftBarButtonItem = nil
		webView.load(URLRequest(url: targetUrl))
	}

	@objc func webViewToolbarDidPressDismiss() {
		dismiss(animated: true)
	}

	private func enterFailedState() {
		navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(reload))
	}
}
