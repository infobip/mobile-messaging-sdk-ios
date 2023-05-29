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
import WebRTCUI
import InAppChat

class OptionListVC: UIViewController, MMInAppChatDelegate, MMPIPUsable {
    @IBOutlet weak var optionsTableV: UITableView!
    @IBOutlet weak var optionsSegmentedC: UISegmentedControl!

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
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .white
            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
        }
    }
    
    @IBAction func onSegmentedChanged(_ sender: Any) {
        optionsTableV.reloadData()
    }
    
    func showChatInNavigation() {
        let vc = MMChatViewController.makeChildNavigationViewController()
        navigationController?.pushViewController(vc, animated: true)
        // customisation out of the SDK, applied to navigation items
        let demoBtn = UIBarButtonItem(title: "demoBtn", style: .plain, target: self, action: #selector(showDemoAlert))
        vc.navigationItem.rightBarButtonItems = [demoBtn]
    }
    
    func showChatModally() {
        let vc = MMChatViewController.makeModalViewController()
        navigationController?.present(vc, animated: true, completion: nil)
    }
    
    func presentRootNavigationVC() {
        let vc = MMChatViewController.makeRootNavigationViewController()
        navigationController?.present(vc, animated: true, completion: nil)
    }

    func presentNavigationVCCustomTrans() {
        let vc = MMChatViewController.makeRootNavigationViewControllerWithCustomTransition()
        navigationController?.present(vc, animated: true, completion: nil)
    }
    
    func presentInTabBar() {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        if let vc = storyboard.instantiateViewController(withIdentifier: "tabController") as? UITabBarController {
            vc.modalPresentationStyle = .fullScreen
            //navigationController?.present(vc, animated: true, completion: nil)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func showReplacedChatInNavigation() {
        let customInputView = CustomInputView(frame: CGRect(x: 0, y: view.frame.height-50,
                                                   width: view.frame.width, height: 50))
        let vc = MMChatViewController.makeCustomViewController(with: customInputView)
        customInputView.setupInputView()
        navigationController?.pushViewController(vc, animated: true)
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

    @objc private func showDemoAlert() {
        let alert = UIAlertController(title: "Hey hi!", message: "Demo text", preferredStyle: .alert)
        self.present(alert, animated: true, completion: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                alert.dismiss(animated: true)
            }
        })
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
        MobileMessaging.webRTCService?.applicationId = webrtcApplicationId
        MobileMessaging.webRTCService?.start({ result in
            print("Calls process started successfully \(result)")
        })
    }
    
    func onCopyPushRegIdToClipbpard() {
        var text = "No push registration Id available yet"
        if let pushReg = MobileMessaging.getInstallation()?.pushRegistrationId {
            UIPasteboard.general.string = pushReg
            text = "Push registration Id copied to clipboard"
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
    
    func onChangeColorTheme() {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        if let vc = storyboard.instantiateViewController(withIdentifier: "setColorTheme") as? ColorThemeTableVC {
            navigationController?.present(vc, animated: true, completion: nil)
        }
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
    
    func enableButtons(enabled: Bool) {
        optionsTableV.isUserInteractionEnabled = enabled
        optionsTableV.alpha = enabled ? 1.0 : 0.3
    }

    private func handleShowChat(_ option: Int) {
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
        guard let suboption = AdvancedChatOptions(rawValue: option) else { return }
        switch suboption {
        case .setLanguage:
            showLanguageVC()
        case .customisedChatInput:
            setCustomSettings()
            showChatInNavigation()
        case .replacedChatInput:
            showReplacedChatInNavigation()
        case .presentSendingContextualData:
            presentAndSendContextualData()
        case .authenticatedChat:
            showAuthenticationVC()
        case .personalize:
            showPersonalizationVC()
        case .depersonalize:
            onDePersonalize()
        case .changeColorTheme:
            onChangeColorTheme()
        }
    }
    
    private func handleWebRTCUI(_ option: Int) {
        guard let suboption = WebRTCUIOptions(rawValue: option) else { return }
        switch suboption {
        case .restartCalls:
            onRestartCalls()
        case .stopCall:
            onTapStopCalls()
        case .copyPushRegIdToClipboard:
            onCopyPushRegIdToClipbpard()
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
        advSettings.inputContainerBackgroundColor           = .orange
        advSettings.typingIndicatorColor                    = .darkGray
        advSettings.sendButtonIcon                          = UIImage(named: "sendIcon")
        advSettings.attachmentButtonIcon                    = UIImage(named: "attachIcon")
        advSettings.isLineSeparatorHidden                   = true
        advSettings.mainFont                                = UIFont(name: "HelveticaNeue-Thin", size: 18.0)
        advSettings.charCountFont                           = UIFont(name: "HelveticaNeue-Bold", size: 18.0)
        MMChatSettings.settings.advancedSettings = advSettings
        MMChatSettings.settings.title = "Overwriting title"
        MMChatSettings.settings.sendButtonTintColor = .white
        MMChatSettings.settings.navBarItemsTintColor = .white
        MMChatSettings.settings.navBarColor = .orange
        MMChatSettings.settings.navBarTitleColor = .white
        MMChatSettings.settings.attachmentPreviewBarsColor = .brown
        MMChatSettings.settings.attachmentPreviewItemsColor = .white
        MMChatSettings.settings.backgroungColor = .orange
        MMChatSettings.settings.errorLabelTextColor = .white
        MMChatSettings.settings.errorLabelBackgroundColor = .red
        MMChatSettings.darkSettings = MMChatSettings()
        MMChatSettings().reversedColors()
        MMChatSettings.darkSettings?.backgroungColor = .black
        MMChatSettings.darkSettings?.advancedSettings.mainTextColor                 = .white
        MMChatSettings.darkSettings?.advancedSettings.mainPlaceholderTextColor      = .lightGray
        MMChatSettings.darkSettings?.advancedSettings.textInputBackgroundColor      = .black
        MMChatSettings.darkSettings?.advancedSettings.inputContainerBackgroundColor = .black
        MMChatSettings.darkSettings?.advancedSettings.typingIndicatorColor          = .darkGray
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
        case .showChat:
            handleShowChat(indexPath.row)
        case .advancedChat:
            handleAdvancedChat(indexPath.row)
        case .webRTCUI:
            handleWebRTCUI(indexPath.row)
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
        delegate?.sendAttachmentData(data, completion: { error in
            if let error = error {
                MMLogDebug(">> Text message failed with error \(error.localizedDescription)")
            } else {
                MMLogDebug(">> Text message sent successfully")
            }
        })
    }
    
    @objc func onSendText() {
        delegate?.sendText(textView.text, completion: { error in
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
