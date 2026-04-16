//
//  AttachmentPreviewController.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2026 Infobip Limited
//  Licensed under the Apache License, Version 2.0
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

    lazy var urlSession: URLSession = {
        let config = MobileMessaging.urlSessionConfiguration
        config.timeoutIntervalForResource = 20
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config)
    }()

    var responseData: MMDownloadResult?

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
        nvc.modalPresentationStyle = .overFullScreen
        nvc.view.backgroundColor = .black
        return nvc
    }

    private func loadAttachment(forURL url: URL) {
        view.addSubview(contentView)
        contentView.startLoading()

        let request = URLRequest(url: attachment.url)
        let task = urlSession.downloadTask(with: request) { [weak self] tempURL, response, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.contentView.stopLoading()

                if let error = error {
                    self.logError("attachment download failed: \(error)")
                    self.shareButtonItem.isEnabled = false
                    self.contentView.showError()
                    return
                }

                guard let tempURL = tempURL, let response = response else {
                    self.shareButtonItem.isEnabled = false
                    self.contentView.showError()
                    return
                }

                if let suggestedFilename = response.suggestedFilename {
                    self.title = suggestedFilename
                }

                let destinationURL = URL.chatAttachmentDestinationUrl(sourceUrl: tempURL, suggestedFileName: response.suggestedFilename)
                do {
                    let fm = FileManager.default
                    if fm.fileExists(atPath: destinationURL.path) {
                        try fm.removeItem(at: destinationURL)
                    }
                    try fm.moveItem(at: tempURL, to: destinationURL)
                } catch {
                    self.logError("attachment file move failed: \(error)")
                    self.shareButtonItem.isEnabled = false
                    self.contentView.showError()
                    return
                }

                let data = try? Data(contentsOf: destinationURL)
                let downloadResult = MMDownloadResult(value: data, destinationURL: destinationURL, error: nil)
                self.responseData = downloadResult
                self.shareButtonItem.isEnabled = true
                self.contentView.showContentFrom(responseData: downloadResult)
            }
        }
        task.resume()
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
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = backgroundTint
        appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: itemsTint]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
    }

    @objc func didPressShareButton() {
        guard let responseData = responseData, let url = responseData.destinationURL else {
            return
        }
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
