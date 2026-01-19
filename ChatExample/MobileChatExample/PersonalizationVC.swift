// 
//  ChatExample/MobileChatExample/PersonalizationVC.swift
//  MobileChatExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import UIKit
import MobileMessaging
#if USING_SPM
import WebRTCUI
import InAppChat
import MobileMessagingLogging
#endif

class PersonalizationVC: UIViewController {
    @IBOutlet weak var phoneTextfield: UITextField!
    @IBOutlet weak var emailTextfield: UITextField!
    @IBOutlet weak var firstnameTextfield: UITextField!
    @IBOutlet weak var lastnameTextfield: UITextField!
    @IBOutlet weak var keepAsLeadToggle: UISwitch!
    
    @IBAction func onDoPersonalization(_ sender: Any) {
        let identity = MMUserIdentity(phones: [phoneTextfield.text ?? "123000000000"], emails: [emailTextfield.text ?? "name@domain.com"], externalUserId: nil)
        let atts = MMUserAttributes(firstName: firstnameTextfield.text ?? "FirstName", middleName: nil, lastName: lastnameTextfield.text ?? "Lastname", tags: nil, gender: .Male, birthday: nil, customAttributes: nil)
        let keepAsLead = keepAsLeadToggle.isOn
        guard let identity = identity else { return }
        MobileMessaging.personalize(forceDepersonalize: true, keepAsLead: keepAsLead, userIdentity: identity, userAttributes: atts) { [weak self] result in
            print(">>>>personalize result " + (result?.mm_message ?? ""))
            self?.view.endEditing(true)
            MMPopOverBar.show(
                textColor: .black,
                backgroundColor: .lightGray,
                icon: MMWebRTCSettings.sharedInstance.iconAlert,
                iconTint: .black,
                message: "Personalisation completed with message: \(result?.mm_message ?? "unknown")",
                duration: 10,
                options: MMPopOverBar.Options(shouldConsiderSafeArea: true,
                                          isStretchable: true),
                completion: nil,
                presenterVC: self?.navigationController ?? self?.parent ?? self!)
        }
    }
}
