//
//  WebViewController.swift
//  MobileMessagingExample
//
//  Created by Andrew Berezhnoy on 04/08/2017.
//

import UIKit

class WebViewController: UIViewController, UIWebViewDelegate {
    private static let toolbarHeight: CGFloat = 64
    public var url: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let url = url,
            let targetUrl = URL(string: url)  else {
                print("URL is missing")
                return
        }
        
        // init toolbar
        let toolbarView = UIToolbar(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: WebViewController.toolbarHeight))
        toolbarView.autoresizingMask = [.flexibleWidth]
        toolbarView.setItems([UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(close))],
                             animated: true)
        view.addSubview(toolbarView)
        
        // init web-view
        let webView = UIWebView()
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.frame = CGRect(x: 0,
                               y: WebViewController.toolbarHeight,
                               width: view.frame.width,
                               height: view.frame.height - WebViewController.toolbarHeight)
        
        webView.loadRequest(URLRequest(url: targetUrl))
        webView.delegate = self
        view.addSubview(webView)
    }
    
    func webView(_ webView: UIWebView, didFailLoadWithError error: Error) {
        print("Error occurred while page loading: \(error)")
    }
    
    func webViewDidStartLoad(_ webView: UIWebView) {
        print("Page loaded successfully")
    }
    
    func close() {
        dismiss(animated: true)
    }
}
