//
//  LanguageTableVC.swift
//  MobileChatExample
//
//  Created by Francisco Fortes on 08/06/2022.
//  Copyright © 2022 Infobip d.o.o. All rights reserved.
//

import Foundation
import UIKit
import MobileMessaging

class PersonalizationVC: UIViewController {
    @IBOutlet weak var phoneTextfield: UITextField!
    @IBOutlet weak var emailTextfield: UITextField!
    @IBOutlet weak var firstnameTextfield: UITextField!
    @IBOutlet weak var lastnameTextfield: UITextField!
    
    @IBAction func onDoPersonalization(_ sender: Any) {
        let identity = MMUserIdentity(phones: [phoneTextfield.text ?? "123000000000"], emails: [emailTextfield.text ?? "name@domain.com"], externalUserId: nil)
        let atts = MMUserAttributes(firstName: firstnameTextfield.text ?? "FirstName", middleName: nil, lastName: lastnameTextfield.text ?? "Lastname", tags: nil, gender: .Male, birthday: nil, customAttributes: nil)
        guard let identity = identity else { return }
        MobileMessaging.personalize(forceDepersonalize: true, userIdentity: identity, userAttributes: atts) { [weak self] result in
            print(">>>>personalize result " + (result?.mm_message ?? ""))
            self?.view.endEditing(true)
            MMPopOverBar.show(
                backgroundColor: .lightGray,
                textColor: .black,
                message: "Personalisation completed with message: \(result?.mm_message ?? "unknown")",
                duration: 10,
                options: MMPopOverBar.Options(shouldConsiderSafeArea: true,
                                          isStretchable: true),
                completion: nil,
                presenterVC: self?.navigationController ?? self?.parent ?? self!)
        }
    }
}
