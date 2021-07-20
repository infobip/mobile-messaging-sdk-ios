//
//  CPWebViewChatViewController.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 14.04.2020.
//

import WebKit

///Key component to use for displaying In-app chat view.
///We support two ways to quickly embed it into your own application:
/// - via Interface Builder: set it as `Custom class` for your view controller object.
/// - programmatically: use one of the `make` methods provided.
open class MMChatViewController: MMMessageComposingViewController, ChatWebViewDelegate, ChatSettingsApplicable, NamedLogger {

	///Will make UINavigationController with ChatViewController as root
	public static func makeRootNavigationViewController() -> MMChatNavigationVC {
		return MMChatNavigationVC.makeChatNavigationViewController()
	}

	//Will make ChatViewController, for usage in navigation
	public static func makeChildNavigationViewController() -> MMChatViewController {
		return MMChatViewController(type: .back)
	}
    
    ///Will make UINavigationController with ChatViewController as root with custom transition
    public static func makeRootNavigationViewControllerWithCustomTransition() -> MMChatNavigationVC {
        return MMChatNavigationVC.makeChatNavigationViewController(transitioningDelegate: ChatCustomTransitionDelegate())
    }
	
	//Will make ChatViewController, for presenting modally
	public static func makeModalViewController() -> MMChatViewController {
		return MMChatViewController(type: .dismiss)
	}
	
	var webView: ChatWebView!
    private var chatWidget: ChatWidget?
    
	override var scrollView: UIScrollView! {
		return webView.scrollView
	}

	override var scrollViewContainer: UIView! {
		return webView
	}
    
    var chatNotAvailableLabel: ChatNotAvailableLabel!
    
	open override func loadView() {
		super.loadView()
		setupWebView()
        setupChatNotAvailableLabel()
	}

	open override func viewDidLoad() {
		super.viewDidLoad()
		MobileMessaging.inAppChat?.webViewDelegate = self
		didEnableControls(false)
		registerToChatSettingsChanges()

        webView.backgroundColor = UIColor.white
        view.backgroundColor = UIColor.white
    }
	
	open override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		MobileMessaging.inAppChat?.isChatScreenVisible = true
        MobileMessaging.inAppChat?.resetMessageCounter()
	}
	
	open override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		MobileMessaging.inAppChat?.isChatScreenVisible = false
	}

	override func didTapSendText(_ text: String) {
		webView.sendMessage(text)
	}
    
    override func textViewDidChange(_ text: String) {
        webView.sendDraft(text)
    }
    
    private lazy var chatAttachmentPicker: ChatAttachmentPicker = ChatAttachmentPicker(delegate: self)
    
    override func utilityButtonClicked() {
        chatAttachmentPicker.present(presentationController: self)
    }
	
	//ChatSettingsApplicable
	func applySettings() {
        guard let settings = MobileMessaging.inAppChat?.settings else {
            return
        }
		
		if let navBarColor = settings.navBarColor {
			navigationController?.navigationBar.barTintColor = navBarColor
		}
		
		if let navBarItemsTintColor = settings.navBarItemsTintColor {
			navigationController?.navigationBar.tintColor = navBarItemsTintColor
		}
		navigationController?.navigationBar.isTranslucent = false
		if let navBarTitleColor = settings.navBarTitleColor {
			navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : navBarTitleColor]
		}
		title = settings.title
		
		if let sendButtonTintColor = settings.sendButtonTintColor {
			composeBarView.buttonTintColor = sendButtonTintColor
            composeBarView.utilityButtonTintColor = sendButtonTintColor
		}
	}
	
	// ChatWebViewDelegate
	func didLoadWidget(_ widget: ChatWidget) {
        chatWidget = widget
        webView.loadWidget(widget)
	}
	
	func didEnableControls(_ enabled: Bool) {
		webView.isUserInteractionEnabled = enabled
        webView.isLoaded = enabled
		composeBarView.isEnabled = enabled
        if enabled {
            MobileMessaging.inAppChat?.resetMessageCounter()
        }
	}
    
    func didReceiveError(_ errors: ChatErrors) {
         if errors == .none {
             chatNotAvailableLabel.hide()
             if !(webView.isLoaded) {
                 webView.reload()
             }
         } else {
             chatNotAvailableLabel.show()
         }
    }
    
    func didOpenPreview(forAttachment attachment: ChatWebAttachment) {
        let vc =  AttachmentPreviewController.makeRootInNavigationController(forAttachment: attachment)
        self.present(vc, animated: true, completion: nil)
    }
	
	// Private
	private func setupWebView() {
		webView = ChatWebView(frame: view.bounds)
		webView.navigationDelegate = self
		webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(webView)
	}
    
    private func setupChatNotAvailableLabel() {
        chatNotAvailableLabel = ChatNotAvailableLabel(frame: CGRect(x: 0, y: -ChatNotAvailableLabel.kHeight, width: self.view.bounds.width, height: ChatNotAvailableLabel.kHeight))
        self.view.addSubview(self.chatNotAvailableLabel)
    }
    
}

extension MMChatViewController: ChatAttachmentPickerDelegate {
    func didSelect(attachment: ChatMobileAttachment) {
        webView.sendMessage(attachment: attachment)
    }
    
    func permissionNotGranted(permissionKeys: [String]?) {
        guard let permissionKeys = permissionKeys else {
            return
        }
        var accessDescription: String? = nil
        for key in permissionKeys {
            if let permissionDescription = Bundle.main.object(forInfoDictionaryKey: key) as? String {
                accessDescription = accessDescription != nil ? "\(accessDescription!)\n\(permissionDescription)" : permissionDescription
            }
        }
        let alert = UIAlertController(title: accessDescription ?? "Required permissions not granted",
                                      message: ChatLocalization.localizedString(forKey: "mm_permissions_alert_message", defaultString: "To give permissions go to Settings"),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: MMLocalization.localizedString(forKey: "mm_button_cancel", defaultString: "Cancel"), style: .cancel, handler: nil))
        if let settingsUrl = NSURL(string: UIApplication.openSettingsURLString, relativeTo: nil) as URL?,
            UIApplication.shared.canOpenURL(settingsUrl) {
            alert.addAction(UIAlertAction(title: ChatLocalization.localizedString(forKey: "mm_button_settings", defaultString: "Settings"), style: .default, handler: { (action) in
                UIApplication.shared.open(settingsUrl, options: [:], completionHandler: nil)
            }))
        }
        self.present(alert, animated: true, completion: nil)
        
    }
    
    func validateAttachmentSize(size: Int) -> Bool {
        return size <= maxUploadAttachmentSize
    }
    
    func attachmentSizeExceeded() {
        let title = ChatLocalization.localizedString(forKey: "mm_attachment_upload_failed_alert_title", defaultString: "Attachment upload failed")
        let message = ChatLocalization.localizedString(forKey: "mm_attachment_upload_failed_alert_message", defaultString: "Maximum allowed size exceeded")
        logError("\(title). \(message) (\(maxUploadAttachmentSize.mbSize))")
        showAlert(title, message: message)
    }
    
    private var maxUploadAttachmentSize: UInt { return chatWidget?.maxUploadContentSize ?? ChatAttachmentUtils.DefaultMaxAttachmentSize}
}

extension MMChatViewController: WKNavigationDelegate {
	public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		guard navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url, UIApplication.shared.canOpenURL(url) else {
			decisionHandler(.allow)
			return
		}
		logDebug("will open URL: \(url)")
		UIApplication.shared.open(url)
		decisionHandler(.cancel)
	}
}
