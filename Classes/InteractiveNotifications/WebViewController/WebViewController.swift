//
//  WebViewController.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 29.03.2020.
//

import WebKit

public class WebViewController: UIViewController, WKUIDelegate {
	var url: String?
	private var webView: WKWebView!
	private var toolbarView: UIToolbar?
	
	/// Tint color of toolbar
	/// - Note: The toolbar is only visible for iOS versions before 13.0
	public var tintColor: UIColor? { set { toolbarView?.tintColor = newValue } get { return toolbarView?.tintColor } }

	/// Bar tint color of toolbar
	/// - Note: The toolbar is only visible for iOS versions before 13.0
	public var barTintColor: UIColor? { set { toolbarView?.barTintColor = newValue } get { return toolbarView?.barTintColor } }

	override public func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = UIColor.black
		let toolbarHeight: CGFloat
		if #available(iOS 13, *) {
			toolbarHeight = 0
		} else {
			toolbarHeight = 64
			toolbarView = UIToolbar(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: toolbarHeight))
			if let toolbarView = self.toolbarView {
				toolbarView.autoresizingMask = [.flexibleWidth]
				toolbarView.setItems([UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(close))], animated: true)
				view.addSubview(toolbarView)
			}
		}

		webView = WKWebView()
		webView.scrollView.backgroundColor = UIColor.black
		webView.backgroundColor = UIColor.black
		webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		webView.contentMode = .scaleAspectFit
		webView.frame = CGRect(x: 0, y: toolbarHeight, width: view.frame.width, height: view.frame.height - toolbarHeight)
		view.addSubview(webView)
	}

	override public func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		guard let url = url, let targetUrl = URL(string: url) else {
			return
		}
		webView.load(URLRequest(url: targetUrl))
	}

	@objc func close() {
		dismiss(animated: true)
	}
}
