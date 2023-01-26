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

class AuthenticatedChatVC: UIViewController, MMInAppChatDelegate {
    @IBOutlet weak var identityTextField: UITextField!
    @IBOutlet weak var identitySegmentedC: UISegmentedControl!
    @IBOutlet weak var fullNameTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        MobileMessaging.inAppChat?.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        MobileMessaging.inAppChat?.jwt = nil
        identityTextField.text = "dsa@asd.com"
        identitySegmentedC.selectedSegmentIndex = 0
        fullNameTextField.text = "John Smith"
    }
    
    @IBAction func doAuthenticateAndPresentChat(_ sender: Any) {
        guard let identityString = identityTextField.text else {
            MMLogError("Identity cannot be empty")
            return
        }
        let emails = identitySegmentedC.selectedSegmentIndex == 0 ? [identityString] : nil
        let phones = identitySegmentedC.selectedSegmentIndex == 1 ? [identityString] : nil
        let externalId = identitySegmentedC.selectedSegmentIndex == 2 ? identityString : nil
        let identity = MMUserIdentity(phones: phones, emails: emails, externalUserId: externalId)
        let nameComponents = fullNameTextField.text?.components(separatedBy: " ")
        let atts = nameComponents == nil ? nil : MMUserAttributes(firstName: nameComponents?.first, middleName: nil, lastName: nameComponents?.last, tags: nil, gender: nil, birthday: nil, customAttributes: nil)
        guard let identity = identity else { return }
        // Note: you only need to call "personalize" once for your user. Only the refreshing of the token should be done before
        // presenting the chat
        MobileMessaging.personalize(forceDepersonalize: true, userIdentity: identity, userAttributes: atts) { [weak self] result in
            if result != nil {
                MMLogError(">>>>Personalize result: " + (result?.mm_message ?? ""))
            } else {
                self?.handleJWT(identityMode: emails != nil ? "email" :
                                    phones != nil ? "msisdn" :
                                    "externalPersonId")
            }
        }
    }
    
    func handleJWT(identityMode: String) {
        guard let identifier = identityTextField.text, let jwt = JWTClaims.generateJWT(identityMode, identifier: identifier) else {
            MMLogError("Could not generate JWT, aborting")
            return
        }
        MobileMessaging.inAppChat?.jwt = jwt // We suggest you freshly generate a new token before presenting the chat (to avoid expirations)
        let vc = MMChatViewController.makeModalViewController()
        self.navigationController?.present(vc, animated: true, completion: nil)
    }
}
