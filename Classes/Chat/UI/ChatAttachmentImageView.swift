// 
//  ChatAttachmentImageView.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import WebKit
import UIKit

class ChatAttachmentPreview: UIView {
    var contentView: UIView?
    let bckgrColor = MMChatSettings.sharedInstance.attachmentPreviewBarsColor ?? .black
    let vTintColor = MMChatSettings.sharedInstance.attachmentPreviewItemsColor ?? .white
    
    lazy var activityIndicatior: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(frame: bounds)
        activityIndicator.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin, .flexibleBottomMargin]
        activityIndicator.color = vTintColor
        activityIndicator.style = .large
        return activityIndicator
    }()
    
    lazy var errorView: UIImageView = {
        let view = UIImageView(frame: bounds)
        view.image = UIImage(mm_chat_named: "fileNotFound")?.withRenderingMode(.alwaysTemplate)
        view.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin, .flexibleBottomMargin]
        view.contentMode = .center
        view.isHidden = true
        view.tintColor = vTintColor
        view.backgroundColor = .clear
        return view
    }()
    
    func startLoading() {
        activityIndicatior.startAnimating()
    }
    func stopLoading() {
        activityIndicatior.stopAnimating()
    }
    func showError() {
        DispatchQueue.mmEnsureMain {
            self.errorView.isHidden = false
        }
    }
    
    func setupViews() {
        backgroundColor = bckgrColor
        if let contentView = contentView {
            addSubview(contentView)
        }
        addSubview(errorView)
        addSubview(activityIndicatior)
    }
    
    func showContentFrom(responseData: DownloadResponse<Data>) {}
}

class ChatAttachmentImagePreview: ChatAttachmentPreview {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView = imageView
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func showContentFrom(responseData: DownloadResponse<Data>) {
        guard let data = responseData.value,
            let image = UIImage(data: data) else {
                showError()
                return
        }
        setImage(image: image)
    }
    
    private lazy var imageView: UIImageView = {
        let imageView = UIImageView(frame: bounds)
        imageView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        return imageView
    }()
    
    private func setImage(image: UIImage) {
        imageView.image = image
        imageView.contentMode = image.size.width < bounds.width && image.size.height < bounds.height ? .center : .scaleAspectFit
    }
}

class ChatAttachmentVideoPreview: ChatAttachmentWebViewPreview {
    override func showContentFrom(responseData: DownloadResponse<Data>) {
        guard let destinationURL = responseData.destinationURL else {
            showError()
            return
        }
        let hexBckgroundColor = bckgrColor.mmHexStringFromColor()
        webView.loadHTMLString("<video style=\"background-color: \(hexBckgroundColor); height: 100%; width: 100%;\" src=\(destinationURL.lastPathComponent) controls playsinline></video>", baseURL: destinationURL.deletingLastPathComponent())
    }
}

class ChatAttachmentWebViewPreview: ChatAttachmentPreview {
    
    init(frame: CGRect, navigationDelegate: WKNavigationDelegate) {
        super.init(frame: frame)
        webView.navigationDelegate = navigationDelegate
        contentView = webView
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: bounds, configuration: configuration)
        webView.contentMode = .scaleAspectFit
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.isOpaque = false
        webView.scrollView.backgroundColor = bckgrColor
        webView.backgroundColor = bckgrColor
        return webView
    }()
    
    override func showContentFrom(responseData: DownloadResponse<Data>) {
        guard let destinationURL = responseData.destinationURL else {
            showError()
            return
        }
        
        webView.load(URLRequest(url: destinationURL))
    }
}
