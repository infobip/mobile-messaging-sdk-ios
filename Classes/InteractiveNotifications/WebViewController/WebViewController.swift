//
//  WebViewController.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 29.03.2020.
//

import WebKit

public class WebViewController: UIViewController, WKUIDelegate, PanModalPresentable {
	var url: String?
	public var webView: WKWebView!

	override public func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = UIColor.black
		webView = WKWebView()
		webView.scrollView.backgroundColor = UIColor.black
		webView.backgroundColor = UIColor.black
		webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		webView.contentMode = .scaleAspectFit
		webView.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height)
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

	public var panScrollable: UIScrollView? {
		return nil
    }
}
