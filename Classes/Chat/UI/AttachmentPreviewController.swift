//
//  AttachmentPreviewController.swift
//  MobileMessaging
//
//  Created by Olga Koroleva on 23.07.2020.
//

import Foundation
import WebKit

class AttachmentPreviewController: MMModalDismissableViewController, ChatSettingsApplicable, NamedLogger {
    
    let attachment: ChatWebAttachment
    
    lazy var contentView: ChatAttachmentPreview = {
        var contentView = ChatAttachmentPreview(frame: view.bounds)
        switch self.attachment.type {
        case .image:
            contentView = ChatAttachmentImagePreview(frame: view.bounds)
        case .video:
            contentView = ChatAttachmentVideoPreview(frame: view.bounds, navigationDelegate: self)
        case .document:
            contentView = ChatAttachmentWebViewPreview(frame: view.bounds, navigationDelegate: self)
        }
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return contentView
    }()
    
    lazy var shareButtonItem: UIBarButtonItem = {
        let barButtonItem =  UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(didPressShareButton))
        barButtonItem.isEnabled = false
        return barButtonItem
    }()
    
    var infoLabel: UILabel?
    
    lazy var sessionManager: SessionManager  = {
        let manager = SessionManager(configuration: MobileMessaging.urlSessionConfiguration)
        manager.session.configuration.timeoutIntervalForResource = 20
        manager.session.configuration.timeoutIntervalForRequest = 20
        return manager
    }()
    
    var responseData: DownloadResponse<Data>?
    
    init(type: CPBackButtonType, attachment: ChatWebAttachment) {
        self.attachment = attachment
        super.init(type: type)
    }
    
    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        super.loadView()
        setupToolbars()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        registerToChatSettingsChanges()
        loadAttachment(forURL: attachment.url)
    }
        
    static func makeRootInNavigationController(forAttachment attachment: ChatWebAttachment) -> UINavigationController {
        let nvc = UINavigationController(rootViewController: AttachmentPreviewController(type: .dismiss, attachment: attachment))
        nvc.modalPresentationStyle = .fullScreen
        nvc.view.backgroundColor = .black
        return nvc
    }
    
    private func loadAttachment(forURL url: URL) {
        
        let destination: DownloadRequest.DownloadFileDestination = { url, urlResponse in
            DispatchQueue.main.async {
                self.title = urlResponse.suggestedFilename
            }
            return (URL.chatAttachmentDestinationUrl(sourceUrl: url, suggestedFileName: urlResponse.suggestedFilename), DownloadRequest.DownloadOptions.removePreviousFile)
        }
        
        view.addSubview(contentView)
        contentView.startLoading()
        
        sessionManager.download(URLRequest(url: attachment.url), to: destination).responseData { [weak self] (downloadResponse) in
            guard let self = self else { return }
            self.contentView.stopLoading()
            if downloadResponse.error != nil {
                self.shareButtonItem.isEnabled = false
                self.contentView.showError()
                return
            }
            self.responseData = downloadResponse
            self.shareButtonItem.isEnabled = ChatAttachmentUtils.isInfoPlistKeyDefined("NSPhotoLibraryAddUsageDescription")
            self.contentView.showContentFrom(responseData: downloadResponse)
        }
    }
    
    private func setupToolbars() {
        //toolbar
        setToolbarItems([UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil), shareButtonItem], animated: true)
        navigationController?.isToolbarHidden = false
        navigationController?.toolbar.isTranslucent = false
        applySettings()
    }
    
    func applySettings() {
        guard MMChatSettings.sharedInstance.shouldSetNavBarAppearance else { return }
        let settings = MMChatSettings.sharedInstance
        let backgroundTint = settings.attachmentPreviewBarsColor ?? UIColor.black
        let itemsTint = settings.attachmentPreviewItemsColor ?? UIColor.white
        navigationController?.toolbar.barTintColor = backgroundTint
        navigationController?.toolbar.tintColor = itemsTint
        navigationController?.navigationBar.tintColor = itemsTint
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : itemsTint]
        navigationController?.navigationBar.barTintColor = backgroundTint
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = backgroundTint
            appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: itemsTint]
            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
        } else {
            navigationController?.navigationBar.isTranslucent = false
        }
    }
    
    @objc func didPressShareButton() {
        guard let responseData = responseData, let url = responseData.destinationURL else {
            return
        }
        /* We do not distinguish by type: all attachments actions are handled by URL, and UIActivityViewController will decide
         based on content what options to display. This is important for saving into Files, where only by having the URL the original
         name can be retrieved, and renaming field is offered */
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activity.completionWithItemsHandler = { [weak self] (type, completed, items, error) in
            self?.logInfo("attachment sharing completed: \(completed) error: \(String(describing: error))")
        }
        
        self.present(activity, animated: true, completion: nil)
    }
}

extension AttachmentPreviewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard navigationResponse.canShowMIMEType else {
            contentView.showError()
            logError("attachment mimeType isn't supported")
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        //PDFs can have external links, they will be disabled.
        guard navigationAction.navigationType != .linkActivated  else {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        contentView.stopLoading()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        contentView.stopLoading()
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        contentView.stopLoading()
    }
}

extension URL {
    static func chatAttachmentDestinationFolderUrl(createIfNotExist: Bool = true) -> URL {
        let fileManager = FileManager.default
        let tempFolderUrl = URL.init(fileURLWithPath: NSTemporaryDirectory())
        
        var destinationFolderURL = tempFolderUrl.appendingPathComponent("com.mobile-messaging.in-app-chat-attachments", isDirectory: true)
        
        var isDir: ObjCBool = true
        if createIfNotExist && !fileManager.fileExists(atPath: destinationFolderURL.path, isDirectory: &isDir) {
            do {
                try fileManager.createDirectory(at: destinationFolderURL, withIntermediateDirectories: true, attributes: nil)
            } catch _ {
                destinationFolderURL = tempFolderUrl
            }
        }
        
        return destinationFolderURL
    }
        
    static func chatAttachmentDestinationUrl(sourceUrl: URL, suggestedFileName: String?) -> URL {
        return URL.chatAttachmentDestinationFolderUrl().appendingPathComponent(suggestedFileName ?? (sourceUrl.absoluteString.sha256() + "." + sourceUrl.pathExtension))
    }
}
