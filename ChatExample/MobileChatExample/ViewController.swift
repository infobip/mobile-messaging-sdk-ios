//
//  ViewController.swift
//  MobileChatExample
//
//  Created by okoroleva on 26.04.2020.
//  Copyright © 2020 Infobip d.o.o. All rights reserved.
//

import Foundation
import UIKit
import MobileMessaging

class ViewController: UIViewController, MMInAppChatDelegate {
    @IBOutlet weak var buttonsStackView: UIStackView!

    override func viewDidLoad() {
		super.viewDidLoad()
		MobileMessaging.inAppChat?.delegate = self
        let jwt = generateJWT(email: "john.wick@babajaga.com",
                              widgetId: "8524cca9-6326-46b5-ab47-680aafefdc27",
                              widgetKeyId: "8068b194-e736-410a-b9ec-7606d270335f",
                              widgetSecretKeyId: "y96Oo+A2xUQeOVVTrgubz6/p5D5arZTwir5YxWPXd7I=")
        print(jwt ?? "error")
	}
	
	@IBAction func showChatInNavigationP(_ sender: Any) {
		let vc = MMChatViewController.makeChildNavigationViewController()
		navigationController?.pushViewController(vc, animated: true)
	}
	@IBAction func showChatModallyP(_ sender: Any) {
		let vc = MMChatViewController.makeModalViewController()
		navigationController?.present(vc, animated: true, completion: nil)
	}
	@IBAction func presentRootNavigationVC(_ sender: Any) {
		let vc = MMChatViewController.makeRootNavigationViewController()
		navigationController?.present(vc, animated: true, completion: nil)
	}

    @IBAction func presentNavigationVCCustomTrans(_ sender: Any) {
        let vc = MMChatViewController.makeRootNavigationViewControllerWithCustomTransition()
        navigationController?.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func presentAndSendContextualData(_ sender: Any) {
        // We first display the chat, and few seconds later (chat should be loaded and connected) we send
        // some contextual data. More data can be sent asynchronously while the chat is active.
        let vc = MMChatViewController.makeModalViewController()
        navigationController?.present(vc, animated: true, completion: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            vc.sendContextualData("{ demoKey: 'InAppChat Metadata Value' }") { error in
                guard let error = error else {
                    print("Medatata was sent")
                    return
                }
                print("Error sending metadata: \(error.localizedDescription)")
            }
        }
    }
    
    func inAppChatIsEnabled(_ enabled: Bool) {
		enableButtons(enabled: enabled)
	}
	
	func enableButtons(enabled: Bool) {
        buttonsStackView.isUserInteractionEnabled = enabled
        buttonsStackView.alpha = enabled ? 1.0 : 0.3
	}
    
    func generateJWT(email: String,
                    widgetId: String,
                    widgetKeyId: String,
                    widgetSecretKeyId: String) -> String? {
        let myHeader = Header(alg: "HS256")
        let randomUniqueString = UUID().uuidString
        let myClaims = JWTClaims(
            jti: randomUniqueString,
            sub: email,
            stp: "email",
            iss: widgetId,
            iat: Date(),
            exp: Date().addingTimeInterval(10), //10 seconds after creation - recommended value
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
