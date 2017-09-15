//
//  WebViewController.swift
//  MobileMessagingExample
//
//  Created by Andrew Berezhnoy on 04/08/2017.
//

import UIKit

class WebViewController: ViewControllerWithToolbar, UIWebViewDelegate {
    let url: URL
	
	init(url: URL) {
		self.url = url
		super.init(nibName: nil, bundle: nil)
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // init web-view
        let webView = UIWebView()
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.frame = CGRect(x: 0,
                               y: ViewControllerWithToolbar.toolbarHeight,
                               width: view.frame.width,
                               height: view.frame.height - WebViewController.toolbarHeight)
        
        webView.loadRequest(URLRequest(url: url))
        webView.delegate = self
        view.addSubview(webView)
    }
    
    func webView(_ webView: UIWebView, didFailLoadWithError error: Error) {
        print("Error occurred while page loading: \(error)")
    }
    
    func webViewDidStartLoad(_ webView: UIWebView) {
        print("Page loaded successfully")
    }
}
