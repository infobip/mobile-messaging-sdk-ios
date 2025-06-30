//
//  AuthenticatedChatVC.swift
//  MobileChatExample
//
//  Created by Francisco Fortes on 26/01/2023.
//  Copyright © 2023 Infobip d.o.o. All rights reserved.
//

import Foundation
import UIKit
import MobileMessaging
#if USING_SPM
import InAppChat
import MobileMessagingLogging
#endif

class AuthenticatedChatVC: UIViewController {
    @IBOutlet weak var identityTextField: UITextField!
    @IBOutlet weak var identitySegmentedC: UISegmentedControl!
    @IBOutlet weak var fullNameTextField: UITextField!
    @IBOutlet weak var keepAsLeadSwitch: UISwitch!

    var emails: [String]?
    var phones: [String]?
    var externalId: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        MobileMessaging.inAppChat?.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        identityTextField.text = "dsa@asd.com"
        identitySegmentedC.selectedSegmentIndex = 0
        fullNameTextField.text = "John Smith"
    }

    @IBAction func doAuthenticateAndPresentChat(_ sender: Any) {
        guard let identityString = identityTextField.text else {
            MMLogError("Identity cannot be empty")
            return
        }
        emails = identitySegmentedC.selectedSegmentIndex == 0 ? [identityString] : nil
        phones = identitySegmentedC.selectedSegmentIndex == 1 ? [identityString] : nil
        externalId = identitySegmentedC.selectedSegmentIndex == 2 ? identityString : nil
        let identity = MMUserIdentity(phones: phones, emails: emails, externalUserId: externalId)
        let nameComponents = fullNameTextField.text?.components(separatedBy: " ")
        let atts = nameComponents == nil ? nil : MMUserAttributes(firstName: nameComponents?.first, middleName: nil, lastName: nameComponents?.last, tags: nil, gender: nil, birthday: nil, customAttributes: nil)
        guard let identity = identity else { return }
        // Note: you only need to call "personalize" once for your user. Only the refreshing of the token should be done before
        // presenting the chat
        MobileMessaging.personalize(forceDepersonalize: true, keepAsLead: keepAsLeadSwitch.isOn, userIdentity: identity, userAttributes: atts) { [weak self] result in
            if result != nil {
                MMLogError(">>>>Personalize result: " + (result?.mm_message ?? ""))
            } else {

                let vc = MMChatViewController.makeModalViewController()
                self?.present(vc, animated: true)
            }
        }
    }
}

extension AuthenticatedChatVC: MMInAppChatDelegate {
    func getJWT() -> String? {
        let identityMode = emails != nil ? "email" :
                            phones != nil ? "msisdn" : "externalPersonId"
        guard let identifier = identityTextField.text, let jwt = JWTClaims.generateJWT(identityMode, identifier: identifier) else {
            MMLogError("Could not generate JWT, aborting")
            return nil
        }
        return jwt
    }
}
