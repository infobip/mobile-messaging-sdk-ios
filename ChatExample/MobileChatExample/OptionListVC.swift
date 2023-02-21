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
            navigationController?.present(vc, animated: true, completion: nil)
        }
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
    
    func onDePersonalize() {
        MobileMessaging.depersonalize() { result, error in
            print(">>>>Depersonalise result: " + "\(result.rawValue)" + "error: " + (error?.localizedDescription ?? "failed"))
        }
    }

    func onTapStopCalls() {
        MobileMessaging.webrtcService?.stopService({ result in
            print("Calls were stopped successfully \(result)")
        })
    }
    
    func onRestartCalls() {
        MobileMessaging.webrtcService?.applicationId = webrtcApplicationId
        MobileMessaging.webrtcService?.start({ result in
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
    /*
     showChatInNavigationP
     showChatModallyP
     presentRootNavigationVC
     presentNavigationVCCustomTrans
     */
    
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
        case .presentSendingContextualData:
            presentAndSendContextualData()
        case .authenticatedChat:
            showAuthenticationVC()
        case .personalize:
            showPersonalizationVC()
        case .depersonalize:
            onDePersonalize()
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

class OptionCell: UITableViewCell {
    @IBOutlet weak var titleLbl: UILabel!
}
