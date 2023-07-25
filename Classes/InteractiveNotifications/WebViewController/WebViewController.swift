//
//  WebViewController.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 29.03.2020.
//

import WebKit

public class MMWebViewController: UINavigationController {
	init(url: String) {
		super.init(rootViewController: MMWebViewControllerBase(url: url))
		if #available(iOS 13.0, *) {
            navigationBar.tintColor = UIColor.label
            navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.label as Any]
            if #available(iOS 15.0, *) {
                let appearance = UINavigationBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.label as Any]
                navigationBar.standardAppearance = appearance
                navigationBar.scrollEdgeAppearance = appearance
            }
		} else {
            navigationBar.isTranslucent = false
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

	public var rootWebViewController: MMWebViewControllerBase? {
		return viewControllers.first as? MMWebViewControllerBase
	}

	public var activityIndicator: MMActivityIndicatorProtocol? {
		set { rootWebViewController?.activityIndicator = newValue }
		get { return rootWebViewController?.activityIndicator }
	}

	public var tintColor: UIColor? {
		set { navigationBar.tintColor = newValue }
		get { return navigationBar.tintColor } }

    public var barTintColor: UIColor? {
        set {
            navigationBar.barTintColor = newValue
            if #available(iOS 15.0, *) {
                navigationBar.standardAppearance.backgroundColor = newValue
                navigationBar.scrollEdgeAppearance?.backgroundColor = newValue
            }
        }
        get { return navigationBar.barTintColor } }
    
	public var titleColor: UIColor? {
		set {
            navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : newValue as Any]
            if #available(iOS 15.0, *) {
                navigationBar.standardAppearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor : newValue as Any]
                navigationBar.scrollEdgeAppearance?.titleTextAttributes = [NSAttributedString.Key.foregroundColor : newValue as Any]
            }
        }
		get { return navigationBar.titleTextAttributes?[NSAttributedString.Key.foregroundColor] as? UIColor } }

	public override var title: String? {
		set { rootWebViewController?.customTitle = newValue }
		get { return rootWebViewController?.title } }
    
    public func applySettings(_ settings: MMWebViewSettings?) {
        guard let settings = settings else {
            return
        }
        if let title = settings.title {
            self.title = title
        }
        if let barTintColor = settings.barTintColor {
            self.barTintColor = barTintColor
        }
        if let titleColor = settings.titleColor {
            self.titleColor = titleColor
        }
        if let tintColor = settings.tintColor {
            self.tintColor = tintColor
        }
    }
}

@objc public protocol MMActivityIndicatorProtocol where Self: UIView {
	func startAnimating()
	func stopAnimating()
}

extension UIActivityIndicatorView: MMActivityIndicatorProtocol {

}

public class MMWebViewControllerBase: UIViewController, WebViewToolbarDelegate, WKNavigationDelegate {
	let url: String
	var customTitle: String? {
		didSet {
			self.title = customTitle
		}
	}
	lazy var webView = WKWebView()
	var activityIndicator: MMActivityIndicatorProtocol? {
		didSet {
			activityIndicator?.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin, .flexibleBottomMargin]
		}
	}

	deinit {
		webView.removeObserver(self, forKeyPath: "title")
	}

	init(url: String) {
		self.url = url
		super.init(nibName: nil, bundle: nil)
		webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		webView.navigationDelegate = self
		webView.contentMode = .scaleAspectFit
		webView.addObserver(self, forKeyPath: "title", options: .new, context: nil)
		webView.isOpaque = false
		if #available(iOS 13, *) {
			webView.scrollView.backgroundColor = UIColor.systemBackground
			webView.backgroundColor = UIColor.systemBackground
		} else {
			webView.scrollView.backgroundColor = UIColor.white
			webView.backgroundColor = UIColor.white
		}
		navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(webViewToolbarDidPressDismiss))

		self.activityIndicator = defaultActivityIndicator()
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override public func viewDidLoad() {
		super.viewDidLoad()

		if #available(iOS 13, *) {
			view.backgroundColor = UIColor.systemBackground
		} else {
			view.backgroundColor = UIColor.white
		}

		webView.frame = view.bounds
		view.addSubview(webView)

		if let activityIndicator = self.activityIndicator {
			view.addSubview(activityIndicator)
		}
	}
	public override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		activityIndicator?.center = view.convert(view.center, from: view.superview)
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

	public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		displayActivityIndicator(false)
	}
	
	public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		if let url = navigationAction.request.url, url.scheme != "http", url.scheme != "https", UIApplication.shared.canOpenURL(url) {
			webView.stopLoading()
			UIApplication.shared.open(url, options: [:], completionHandler: {_ in
				self.stopAndDismiss(animated: false)
			})
			decisionHandler(WKNavigationActionPolicy.cancel)
		} else {
			decisionHandler(WKNavigationActionPolicy.allow)
		}
	}

	private func displayActivityIndicator(_ isVisible: Bool) {
        DispatchQueue.main.async {
            self.webView.isHidden = isVisible
            self.activityIndicator?.isHidden = !isVisible
            if isVisible {
                self.activityIndicator?.startAnimating()
            } else {
                self.activityIndicator?.stopAnimating()
            }
        }
	}

	@objc func reload() {
		guard let targetUrl = URL(string: url) else {
			return
		}
		displayActivityIndicator(true)
		navigationItem.leftBarButtonItem = nil
		webView.load(URLRequest(url: targetUrl))
	}

	@objc func webViewToolbarDidPressDismiss() {
		stopAndDismiss(animated: true)
	}
	
	private func stopAndDismiss(animated: Bool) {
		activityIndicator?.stopAnimating()
		webView.stopLoading()
		dismiss(animated: animated)
	}

	private func enterFailedState() {
		displayActivityIndicator(false)
		navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(reload))
	}

	private func defaultActivityIndicator() -> UIActivityIndicatorView {
		let indicator = UIActivityIndicatorView()
		if #available(iOS 13, *) {
			indicator.color = UIColor.systemGray
			indicator.style = .large
		} else {
			indicator.style = .gray
		}
		return indicator
	}
}
