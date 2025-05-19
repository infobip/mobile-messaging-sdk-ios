//
//  OptionListVC.swift
//  MobileChatExample
//
//  Created by Francisco Fortes on 10/02/2023.
//  Copyright © 2023 Infobip d.o.o. All rights reserved.
//

import Foundation
import UIKit
import MobileMessaging
import SwiftUI
#if USING_SPM
import InAppChat
import MobileMessagingLogging
import WebRTCUI
#endif

class OptionListVC: UIViewController, MMInAppChatDelegate {
    
    @IBOutlet weak var optionsTableV: UITableView!
    @IBOutlet weak var optionsSegmentedC: UISegmentedControl!
    private var chatVC: MMChatViewController?
    private var isLightModeOn = true

    override func viewDidLoad() {
        super.viewDidLoad()
        MobileMessaging.inAppChat?.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        resetNavBarAppearance() // chat view controller may modify navigation appearance - we reset it to default
    }

    private func resetNavBarAppearance() {
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.barTintColor = .white
        navigationController?.navigationBar.backgroundColor = .white
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
    }
    
    @IBAction func onSegmentedChanged(_ sender: Any) {
        optionsTableV.reloadData()
    }

    func showChatInNavigation() {
        chatVC = MMChatViewController.makeChildNavigationViewController()
        let demoBtn = UIBarButtonItem(title: "Change Theme", style: .plain, target: self, action: #selector(onChangeTheme))
        chatVC?.navigationItem.rightBarButtonItems = [demoBtn]
        guard let vc = chatVC else { return }
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func showChatModally() {
        let vc = MMChatViewController.makeModalViewController()
        navigationController?.present(vc, animated: true)

    }
    
    func presentRootNavigationVC() {
        let vc = MMChatViewController.makeRootNavigationViewController()
        navigationController?.present(vc, animated: true)
    }

    func presentNavigationVCCustomTrans() {
        let vc = MMChatViewController.makeRootNavigationViewControllerWithCustomTransition()
        navigationController?.present(vc, animated: true)
    }
    
    func presentInTabBar() {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        if let vc = storyboard.instantiateViewController(withIdentifier: "tabController") as? UITabBarController {
            vc.modalPresentationStyle = .fullScreen
            //navigationController?.present(vc, animated: true, completion: nil)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func onShowSwiftUIChat() {
        let vc = UIHostingController(rootView: ExternalInputChatView())
        navigationController?.present(vc, animated: true)
    }
    
    func onShowSwiftUIDefaultChat() {
        let vc = UIHostingController(rootView: DefaultChatView())
        navigationController?.present(vc, animated: true)
    }
    
    func onExternalUIKitChat() {
        let vc = ExternalChatInputViewController()
        MMChatSettings.sharedInstance.shouldHandleKeyboardAppearance = false
        MMChatSettings.sharedInstance.shouldUseExternalChatInput = true
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func showReplacedChatInNavigation() {
        let customInputView = CustomInputView(frame: CGRect(x: 0, y: view.frame.height-50,
                                                   width: view.frame.width, height: 50))
        let vc = MMChatViewController.makeCustomViewController(with: customInputView)
        customInputView.setupInputView()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func onSwiftUIChatWithCustomNavigation() {
        let vc = UIHostingController(rootView: ExternalInputChatViewWithCustomNavigation())
        navigationController?.present(vc, animated: true)
    }
    
    func onLivechatWidgetAPI()  {
        let vc = UIHostingController(rootView: LiveChatAPIView())
        navigationController?.present(vc, animated: true)
    }
    
    func presentAndSendContextualData() {
        // We first display the chat, and few seconds later (chat should be loaded and connected) we send
        // some contextual data. More data can be sent asynchronously while the chat is active.
        let vc = MMChatViewController.makeModalViewController()
        navigationController?.present(vc, animated: true, completion: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            vc.sendContextualData("{ demoKey: 'InAppChat Metadata Value' }") { error in
                guard let error = error else {
                    MMLogInfo("Medatata was sent")
                    return
                }
                MMLogError(("Error sending metadata: \(error.localizedDescription)"))
            }
        }
    }

    @objc private func onChangeTheme() {
        /*
        Themes are defined in web side, under your widget's setup => Themes => Advanced customisation.
        Please check widget documentation for more details: https://www.infobip.com/docs/live-chat/widget-customization
        In this example, we show how to change, in runtime, between two custom modes: dark and light.
         {
           "themes": {
             "default": {
               "lc-chat-message-agent-bubble-background-color": "#f7f7f7",
               "lc-chat-message-agent-bubble-text-color": "#000"
             },
             "dark": {
               "lc-chat-message-agent-bubble-background-color": "#000",
               "lc-chat-message-agent-bubble-text-color": "#f7f7f7"
             }
           }
         }
         */
        isLightModeOn = !isLightModeOn
        chatVC?.setWidgetTheme( isLightModeOn ? "default" : "dark") { error in
            print(">>>>Theme changed with: " + (error?.localizedDescription ?? "Success"))
        }
    }

    func onDePersonalize() {
        MobileMessaging.depersonalize() { result, error in
            print(">>>>Depersonalise result: " + "\(result.rawValue)" + "error: " + (error?.localizedDescription ?? "failed"))
        }
    }

    func onTapStopCalls() {
        MobileMessaging.webRTCService?.stopService({ result in
            print("Calls were stopped successfully \(result)")
        })
    }
    
    func onRestartCalls() {
        MobileMessaging.webRTCService?.configurationId = webrtcConfigurationId
        MobileMessaging.webRTCService?.start({ result in
            print("Calls process started successfully \(result)")
        })
    }
    
    func onCopyIdentityToClipboard() {
        var text = "No WebRTC identity available yet"
        UIPasteboard.general.string = ""
        if let identity = MobileMessaging.webRTCService?.identity {
            UIPasteboard.general.string = identity
            text = "Identity copied to clipboard"
        }
        MMPopOverBar.show(
            backgroundColor: .black,
            textColor: .white,
            message: text,
            duration: 5,
            options: MMPopOverBar.Options(shouldConsiderSafeArea: true,
                                      isStretchable: true),
            presenterVC: self.navigationController ?? self.parent ?? self)
    }
    
    func showLanguageVC() {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        if let vc = storyboard.instantiateViewController(withIdentifier: "setLanguage") as? LanguageTableVC {
            navigationController?.present(vc, animated: true, completion: nil)
        }
    }
    
    func showPersonalizationVC() {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        if let vc = storyboard.instantiateViewController(withIdentifier: "personalization") as? PersonalizationVC {
            navigationController?.present(vc, animated: true, completion: nil)
        }
    }
    
    func showAuthenticationVC() {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        if let vc = storyboard.instantiateViewController(withIdentifier: "authentication") as? AuthenticatedChatVC {
            navigationController?.present(vc, animated: true, completion: nil)
        }
    }
        
    func inAppChatIsEnabled(_ enabled: Bool) {
        enableButtons(enabled: enabled)
    }

    // To control the UI presentation of errors, this delegate method needs to be declared. Otherwise, a banner will be presented by default
//    func didReceiveException(_ exception: MMChatException) -> MMChatExceptionDisplayMode  {
//        print(exception.message ?? "Exception code \(exception.code)")
//        return .noDisplay // you can alternatively allow displaying the default banner with .displayDefaultAlert
//    }

    func attachmentSizeExceeded(_ maxSize: UInt) {
        MMLogDebug("Could not upload attachment as it exceeded the max size allowed \(maxSize)")
    }
    
    func enableButtons(enabled: Bool) {
        optionsTableV.isUserInteractionEnabled = enabled
        optionsTableV.alpha = enabled ? 1.0 : 0.3
    }
    
    func onSendContextualDataDidTap() {
        let alertController = UIAlertController(title: "Send contextual data", message: "", preferredStyle: UIAlertController.Style.alert)
        alertController.addTextField { (textField : UITextField!) -> Void in
            textField.placeholder = "Message"
        }
        let saveAction = UIAlertAction(title: "Send", style: UIAlertAction.Style.default, handler: { alert -> Void in
            guard let textField = alertController.textFields?.first else { return }
            guard let text = textField.text else { return }
            MobileMessaging.inAppChat?.sendContextualData("{ demoKey: \(text)}")
        })
        let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertAction.Style.default, handler: {
            (action : UIAlertAction!) -> Void in })
        
        alertController.addAction(saveAction)
        alertController.addAction(cancelAction)
        
        self.present(alertController, animated: true)
    }

    private func handleUIKitChat(_ option: Int) {
        MMChatSettings.sharedInstance.shouldHandleKeyboardAppearance = true
        MMChatSettings.sharedInstance.shouldUseExternalChatInput = false
        BadgeCounterHandler.clearBadge()
        guard let suboption = ShowChatOptions(rawValue: option) else { return }
        switch suboption {
        case .pushNavigationItem:
            showChatInNavigation()
        case .presentModal:
            showChatModally()
        case .presentRootNavVC:
            presentRootNavigationVC()
        case .presentRootNavVCCustomTansition:
            presentNavigationVCCustomTrans()
        case .showInTabBar:
            presentInTabBar()
        }
    }

    private func handleAdvancedChat(_ option: Int) {
        MMChatSettings.sharedInstance.shouldHandleKeyboardAppearance = true
        MMChatSettings.sharedInstance.shouldUseExternalChatInput = false
        guard let suboption = AdvancedChatOptions(rawValue: option) else { return }
        switch suboption {
        case .setLanguage:
            showLanguageVC()
        case .customisedChatInput:
            setCustomSettings()
            showChatInNavigation()
        case .replacedChatInput:
            BadgeCounterHandler.clearBadge()
            showReplacedChatInNavigation()
        case .presentSendingContextualData:
            BadgeCounterHandler.clearBadge()
            presentAndSendContextualData()
        case .sendContextualData:
            onSendContextualDataDidTap()
        case .authenticatedChat:
            showAuthenticationVC()
        case .personalize:
            showPersonalizationVC()
        case .depersonalize:
            onDePersonalize()
        case .externalChatInputVC:
            BadgeCounterHandler.clearBadge()
            onExternalUIKitChat()
        case .widgetAPI:
            onLivechatWidgetAPI()
        }
    }
    
    private func handleSwiftUIOptions(_ option: Int) {
        BadgeCounterHandler.clearBadge()
        guard let suboption = SwiftUIChatOptions(rawValue: option) else { return }
        switch suboption {
        case .defaultSwiftUIChat:
            onShowSwiftUIDefaultChat()
        case .swiftUIChatWithExternalInput:
            onShowSwiftUIChat()
        case .swiftUIChatWithCustomNavigation:
            onSwiftUIChatWithCustomNavigation()
        }
    }
    
    
    private func handleWebRTCUI(_ option: Int) {
        guard let suboption = WebRTCUIOptions(rawValue: option) else { return }
        switch suboption {
        case .restartCalls:
            onRestartCalls()
        case .stopCall:
            onTapStopCalls()
        case .copyIdentityToClipboard:
            onCopyIdentityToClipboard()
        }
    }
    
    private func setCustomSettings() {
        let advSettings = MMAdvancedChatSettings()
        advSettings.textContainerTopMargin                  = 8.0
        advSettings.textContainerBottomMargin               = 1.0
        advSettings.textContainerLeftPadding                = 10.0
        advSettings.textContainerRightPadding               = 20.0
        advSettings.textContainerTopPadding                 = 1.0
        advSettings.textContainerCornerRadius               = 8.0
        advSettings.textViewTopMargin                       = 2.0
        advSettings.placeholderHeight                       = 30.0
        advSettings.placeholderSideMargin                   = 42.0
        advSettings.placeholderTopMargin                    = 2.0
        advSettings.buttonHeight                            = 44.0
        advSettings.buttonTouchableOverlap                  = 6.0
        advSettings.buttonRightMargin                       = 1.0
        advSettings.buttonBottomMargin                      = 1.0
        advSettings.utilityButtonWidth                      = 40.0
        advSettings.utilityButtonHeight                     = 40.0
        advSettings.utilityButtonBottomMargin               = 2.0
        advSettings.initialHeight                           = 50.0
        advSettings.mainTextColor                           = .black
        advSettings.mainPlaceholderTextColor                = .orange
        advSettings.textInputBackgroundColor                = .white
        advSettings.typingIndicatorColor                    = .darkGray
        advSettings.sendButtonIcon                          = UIImage(named: "sendIcon")
        advSettings.attachmentButtonIcon                    = UIImage(named: "attachIcon")
        advSettings.isLineSeparatorHidden                   = true
        advSettings.mainFont                                = UIFont(name: "HelveticaNeue-Thin", size: 18.0)
        advSettings.charCountFont                           = UIFont(name: "HelveticaNeue-Bold", size: 18.0)
        MMChatSettings.settings.advancedSettings = advSettings
        MMChatSettings.settings.title = "Overwriting title"
        MMChatSettings.settings.sendButtonTintColor = .white
        MMChatSettings.settings.chatInputSeparatorLineColor = .white
        MMChatSettings.settings.navBarItemsTintColor = .white
        MMChatSettings.settings.navBarColor = .orange
        MMChatSettings.settings.navBarTitleColor = .white
        MMChatSettings.settings.attachmentPreviewBarsColor = .brown
        MMChatSettings.settings.attachmentPreviewItemsColor = .white
        MMChatSettings.settings.backgroundColor = .orange
        MMChatSettings.settings.errorLabelTextColor = .white
        MMChatSettings.settings.errorLabelBackgroundColor = .red
        MMChatSettings.settings.widgetTheme = "dark" // You need to have this theme defined in your widget's setup. See method 'onChangeTheme' for more info.
    }

// Uncomment if you want to handle call UI here.
//    func showCallUI(in callController: MMCallController) {
//        PIPKit.show(with: callController)
//    }
}

extension OptionListVC: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let option = MainOptions(rawValue: optionsSegmentedC.selectedSegmentIndex) else { return 0 }
        return option.caseCount
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "optionCell") as? OptionCell else {
            return UITableViewCell()
        }
        let option = MainOptions(rawValue: optionsSegmentedC.selectedSegmentIndex)
        cell.titleLbl.text = option?.subOptionTitle(for: indexPath.row)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let option = MainOptions(rawValue: optionsSegmentedC.selectedSegmentIndex) else { return }
        switch option {
        case .uiKitChat:
            handleUIKitChat(indexPath.row)
        case .advancedChat:
            handleAdvancedChat(indexPath.row)
        case .webRTCUI:
            handleWebRTCUI(indexPath.row)
        case .swiftUIChat:
            handleSwiftUIOptions(indexPath.row)
        }
    }
}

class CustomInputView: UIView, MMChatComposer, UITextViewDelegate {
    weak var delegate: MMComposeBarDelegate?
    private static let elementSize = CGRect(x: 0, y: 0, width: 50, height: 50)
    let textView = UITextView(frame: CustomInputView.elementSize)
    public func setupInputView() {
        let stackView = UIStackView(frame: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height))
        stackView.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin, .flexibleBottomMargin]
        stackView.axis = .horizontal
        let sendPicBtn = UIButton(frame: CustomInputView.elementSize)
        sendPicBtn.setTitle("Send Picture", for: .normal)
        sendPicBtn.tintColor = .white
        sendPicBtn.addTarget(self, action: #selector(onSendPic), for: .touchUpInside)
        let sendTextBtn = UIButton(frame: CustomInputView.elementSize)
        sendTextBtn.setTitle("Send Text", for: .normal)
        sendTextBtn.tintColor = .white
        sendTextBtn.addTarget(self, action: #selector(onSendText), for: .touchUpInside)
        textView.delegate = self
        textView.backgroundColor = .white
        textView.text = "Hello world!"
        stackView.addArrangedSubview(sendPicBtn)
        stackView.addArrangedSubview(sendTextBtn)
        stackView.addArrangedSubview(textView)
        stackView.backgroundColor = .blue
        stackView.distribution = .fillEqually
        self.addSubview(stackView)
    }
    
    @objc func onSendPic() {
        guard let data = UIImage(named: "alphaLogo")?.pngData() else { return }
        let payload = MMLivechatBasicPayload(fileName: "alphaLogo", data: data)
        delegate?.send(payload, completion: { error in
            if let error = error {
                MMLogDebug(">> Text message failed with error \(error.localizedDescription)")
            } else {
                MMLogDebug(">> Text message sent successfully")
            }
        })
    }
    
    @objc func onSendText() {
        delegate?.send(textView.text.livechatBasicPayload, completion: { error in
            if let error = error {
                MMLogDebug(">> Text message failed with error \(error.localizedDescription)")
            } else {
                MMLogDebug(">> Text message sent successfully")
            }
        })
    }
        
    func textViewDidChange(_ textView: UITextView) {
        delegate?.textDidChange(textView.text, completion: { error in
            if let error = error {
                MMLogDebug(">> Text did change call failed with error \(error.localizedDescription)")
            } else {
                MMLogDebug(">> Text did change call sent successfully")
            }
        })
    }
    
    override func becomeFirstResponder() -> Bool {
        return textView.becomeFirstResponder()
    }
    
    override var canBecomeFirstResponder: Bool {
        get {
            return textView.canBecomeFirstResponder
        }
    }
    
    override var isFirstResponder: Bool {
        get {
            return textView.isFirstResponder
        }
    }
}

class OptionCell: UITableViewCell {
    @IBOutlet weak var titleLbl: UILabel!
}
