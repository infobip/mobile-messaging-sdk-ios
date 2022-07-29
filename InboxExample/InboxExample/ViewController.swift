//
//  ViewController.swift
//  InboxExample
//
//  Created by Andrey Kadochnikov on 25.05.2022.
//

import UIKit
import MobileMessaging

class ViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var inboxBtn: BadgeButton!
    @IBOutlet weak var depersonalizeBtn: UIButton!
    @IBOutlet weak var externalUserIdTextField: UITextField!
    @IBOutlet weak var personalizeBtn: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateControls()
        updateInboxMessagesCounters()
        
        // Here we subscribe for MMNotificationRegistrationUpdated to be notified when MM SDK has registered succesfully and ready to be used
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.updateControls(_:)), name: NSNotification.Name(rawValue: MMNotificationRegistrationUpdated), object: nil)
        
        // Here we subscribe for possible counter update that may be triggered by another screen (i.e. Inbox screen)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.updateBadge(_:)), name: NSNotification.Name.inboxCountersUpdated, object: nil)
    }
    
    @objc func updateBadge(_ notification: Notification? = nil) {
        if let unreadCount = notification?.userInfo?[NotificationKeys.unreadCount] as? Int {
            self.inboxBtn.badge = "\(unreadCount)"
        }
    }
    
    @objc func updateControls(_ notification: Notification? = nil) {
        externalUserIdTextField.isEnabled = isPushRegistrationAvailable() && !isUserPersonalizedWithExternalUserId()
        externalUserIdTextField.text = MobileMessaging.getUser()?.externalUserId
        personalizeBtn.isEnabled = externalUserIdTextField.text?.isEmpty == false && !isUserPersonalizedWithExternalUserId()
        depersonalizeBtn.isEnabled = isUserPersonalizedWithExternalUserId()
        inboxBtn.isEnabled = isUserPersonalizedWithExternalUserId()
    }
    
    func updateInboxMessagesCounters() {
        if let externalUserId = MobileMessaging.getUser()?.externalUserId {
            self.showActivityIndicator()
            MobileMessaging.inbox?.fetchInbox(externalUserId: externalUserId, options: MMInboxFilterOptions.init(fromDateTime: nil, toDateTime: nil, topic: nil, limit: 0), completion: { inbox, error in
                assert(Thread.isMainThread)
                self.hideActivityIndicator(nil)
                self.showAlertIfErrorPresent(error)
                if let unreadCount =  inbox?.countUnread {
                    self.inboxBtn.badge = unreadCount > 0 ? "\(unreadCount)" : nil
                }
            })
        }
    }
    
    @IBAction func depersonalize(_ sender: Any) {
        self.showActivityIndicator()
        MobileMessaging.depersonalize { status, error in
            assert(Thread.isMainThread)
            self.hideActivityIndicator(nil)
            self.showAlertIfErrorPresent(error)
            self.updateControls()
            self.inboxBtn.badge = nil
        }
    }
    
    @IBAction func personalize(_ sender: Any) {
        externalUserIdTextField.resignFirstResponder()
        if let externalUserId = externalUserIdTextField.text, let userIdentity = MMUserIdentity(phones: nil, emails: nil, externalUserId: externalUserId) {
            self.showActivityIndicator()
            MobileMessaging.personalize(forceDepersonalize: true, userIdentity: userIdentity, userAttributes: nil) { error in
                assert(Thread.isMainThread)
                self.hideActivityIndicator(nil)
                self.showAlertIfErrorPresent(error)
                self.updateControls()
                self.updateInboxMessagesCounters()
            }
        }
    }
    
    @IBAction func externalUserIdChanged(_ sender: Any) {
        personalizeBtn.isEnabled = externalUserIdTextField.text?.isEmpty == false
    }
    
    fileprivate func isPushRegistrationAvailable() -> Bool {
        return MobileMessaging.getInstallation()?.pushRegistrationId?.isEmpty == false
    }
    
    fileprivate func isUserPersonalizedWithExternalUserId() -> Bool {
        return MobileMessaging.getUser()?.externalUserId != nil && MobileMessaging.getUser()?.externalUserId?.isEmpty == false
    }
}

