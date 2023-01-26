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
            print("Identity cannot be empty")
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
                print(">>>>Personalize result: " + (result?.mm_message ?? ""))
            } else {
                self?.handleJWT(identityMode: emails != nil ? "email" :
                                    phones != nil ? "msisdn" :
                                    "externalPersonId")
            }
        }
    }
    
    func handleJWT(identityMode: String) {
        guard let jwt = generateJWT(identityMode) else {
            print("Could not generate JWT, aborting")
            return
        }
        MobileMessaging.inAppChat?.jwt = jwt // We suggest you freshly generate a new token before presenting the chat (to avoid expirations)
        let vc = MMChatViewController.makeModalViewController()
        self.navigationController?.present(vc, animated: true, completion: nil)
    }
    
    func generateJWT(_ identityMode: String) -> String? {
        guard let identifier = identityTextField.text else { return nil }
        let widgetId = "<# your widget ID #>" // All this values can be obtained in your widget's configuration
        let widgetKeyId = "<# your widget key ID #>" // Always define key and secret as obfuscated strings, for safety!!
        let widgetSecretKeyId = "<# your widget secret key ID #>"
        let myHeader = Header(alg: "HS256")
        let randomUniqueString = UUID().uuidString
        let myClaims = JWTClaims(
            jti: randomUniqueString,
            sub: identifier,
            stp: identityMode,
            iss: widgetId,
            iat: Date(),
            exp: Date().addingTimeInterval(20), // 20 seconds after creation - recommended value
            ski: widgetKeyId,
            sid: randomUniqueString) // This is potentially not needed once we use Logout function
        var myJWT = JWT(header: myHeader, claims: myClaims)
        guard let secretKeyIdData = Data(base64Encoded: widgetSecretKeyId, options: .ignoreUnknownCharacters) else {
            print("Unable to decode the base64 secret key Id")
            return nil
        }
        let jwtSigner = JWTSigner.hs256(key: secretKeyIdData)
        guard let signedJWT = try? myJWT.sign(using: jwtSigner) else {
            print("Unable to prepare the signed JWT to authenticate into the chat")
            return nil
        }
        return signedJWT
    }
}
