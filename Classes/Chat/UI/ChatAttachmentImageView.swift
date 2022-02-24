//
//  ChatAttachmentImageView.swift
//  MobileMessaging
//
//  Created by Olga Koroleva on 02.09.2020.
//

import Foundation
import WebKit

class ChatAttachmentPreview: UIView {
    var contentView: UIView?
    
    lazy var activityIndicatior: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(frame: bounds)
        activityIndicator.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin, .flexibleBottomMargin]
        if #available(iOS 13, *) {
            activityIndicator.color = UIColor.white
            activityIndicator.style = .large
        } else {
            activityIndicator.style = .whiteLarge
        }
        return activityIndicator
    }()
    
    lazy var errorView: UIImageView = {
        let view = UIImageView(frame: bounds)
        view.image = UIImage(mm_named: "fileNotFound")?.withRenderingMode(.alwaysTemplate)
        view.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin, .flexibleBottomMargin]
        view.contentMode = .center
        view.isHidden = true
        view.tintColor = .white
        view.backgroundColor = .clear
        return view
    }()
    
    func startLoading() {
        activityIndicatior.startAnimating()
    }
    func stopLoading() {
        activityIndicatior.stopAnimating()
    }
    func showError(){
        errorView.isHidden = false
    }
    
    func setupViews() {
        backgroundColor = .black
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
        
        webView.loadHTMLString("<video style=\"background-color: #000000; height: 100%; width: 100%;\" src=\(destinationURL.lastPathComponent) controls playsinline></video>", baseURL: destinationURL.deletingLastPathComponent())
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
        webView.scrollView.backgroundColor = .black
        webView.backgroundColor = .black
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
