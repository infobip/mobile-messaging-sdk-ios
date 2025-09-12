//
//  SettingsViewController.swift
//  MobileMessagingExample
//
//  Created by okoroleva on 28.04.16.
//

import UIKit
import MobileMessaging

#if canImport(MobileMessagingInbox)
import MobileMessagingInbox
#endif

class SettingsViewController : UIViewController, UITextFieldDelegate {
	static let kMSISDNValidationRegExp = "^[0-9]{4,17}$"

	@IBOutlet weak var msisdsTextField: UITextField!
	@IBOutlet weak var activityIndicator: UIActivityIndicatorView!
	@IBOutlet weak var sendMSISDNButton: UIButton!
	@IBOutlet weak var externalUserIdTextField: UITextField!
	@IBOutlet weak var personalizeButton: UIButton!
	@IBOutlet weak var depersonalizeButton: UIButton!
	@IBOutlet weak var fetchInboxAllButton: UIButton!
	@IBOutlet weak var fetchInboxSingleTopicButton: UIButton!
	@IBOutlet weak var fetchInboxMultiTopicsButton: UIButton!
	
	private var currentExternalUserId: String?

	override func viewDidLoad() {
		super.viewDidLoad()
		msisdsTextField.delegate = self
		msisdsTextField.text = MobileMessaging.getUser()?.phones?.first
		
		// Set placeholder for external user ID field
		externalUserIdTextField.placeholder = "Enter External User ID"
		
		// Fetch current user state from server
		fetchUserAndUpdateUI()
	}

	//MARK: UITextFieldDelegate
	func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
		let cs = CharacterSet.decimalDigits
		let nsString : NSString = (msisdsTextField.text ?? "") as NSString
		var string = nsString.replacingCharacters(in: range, with: string)
		string = string.components(separatedBy: cs.inverted).joined(separator: "")
		msisdsTextField.text = string

		return false
	}

	//MARK: Actions
	@IBAction func sendMSISDNButtonClicked(_ sender: UIButton) {
		guard let msisdn = msisdsTextField.text else {
			return
		}

		showActivityIndicator()

		do {
			try validateFormat(msisdn)
			if let user = MobileMessaging.getUser() {
				user.phones = [msisdn]
				MobileMessaging.saveUser(user) { (error) -> () in
					DispatchQueue.main.async {
						self.hideActivityIndicator {
							self.showResultAlert(error)
						}
					}
				}
			}
		} catch let error as NSError {
			hideActivityIndicator {
				self.showResultAlert(error)
			}
		}
	}

	@IBAction func personalizeButtonClicked(_ sender: UIButton) {
		guard let externalUserId = externalUserIdTextField.text, !externalUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
			showAlert(title: "Invalid Input", message: "Please enter a valid External User ID")
			return
		}
		
		guard let userIdentity = MMUserIdentity(phones: nil, emails: nil, externalUserId: externalUserId) else {
			print("❌ Failed to create MMUserIdentity")
			showAlert(title: "Personalization Failed", message: "Failed to create user identity")
			return
		}
		
		showActivityIndicator()
		
		MobileMessaging.personalize(withUserIdentity: userIdentity, userAttributes: nil) { error in
			DispatchQueue.main.async {
				self.hideActivityIndicator {
					if let error = error {
						print("❌ Personalization failed: \(error.localizedDescription)")
						self.showAlert(title: "Personalization Failed", message: error.localizedDescription)
					} else {
						print("✅ Personalization successful with externalUserId: \(externalUserId)")
						self.currentExternalUserId = externalUserId
						self.updateUIForUserState()
						self.showAlert(title: "Personalization Success", message: "User personalized with externalUserId: \(externalUserId)")
					}
				}
			}
		}
	}

	@IBAction func depersonalizeButtonClicked(_ sender: UIButton) {
		let alert = UIAlertController(
			title: "Confirm Depersonalization", 
			message: "Are you sure you want to depersonalize? This will remove your External User ID and you won't be able to fetch inbox messages until you personalize again.", 
			preferredStyle: .alert
		)
		
		let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
		let confirmAction = UIAlertAction(title: "Depersonalize", style: .destructive) { _ in
			self.performDepersonalization()
		}
		
		alert.addAction(cancelAction)
		alert.addAction(confirmAction)
		
		present(alert, animated: true, completion: nil)
	}
	
	fileprivate func performDepersonalization() {
		showActivityIndicator()
		
		MobileMessaging.depersonalize { status, error in
			DispatchQueue.main.async {
				self.hideActivityIndicator {
					if let error = error {
						print("❌ Depersonalization failed: \(error.localizedDescription)")
						self.showAlert(title: "Depersonalization Failed", message: error.localizedDescription)
					} else {
						print("✅ Depersonalization successful")
						self.currentExternalUserId = nil
						self.externalUserIdTextField.text = ""
						self.updateUIForUserState()
						self.showAlert(title: "Depersonalization Success", message: "User has been depersonalized")
					}
				}
			}
		}
	}

	@IBAction func fetchInboxSingleTopicButtonClicked(_ sender: UIButton) {
		guard let externalUserId = currentExternalUserId else {
			showAlert(title: "No User ID", message: "Please personalize first to fetch inbox")
			return
		}
		let options = MMInboxFilterOptions(fromDateTime: nil, toDateTime: nil, topic: "Promotions", limit: nil)
		MobileMessaging.inbox?.fetchInbox(externalUserId: externalUserId, options: options) { inbox, error in
			DispatchQueue.main.async {
				if let error = error {
					print("❌ Fetch inbox (single topic) failed: \(error.localizedDescription)")
					self.showAlert(title: "Fetch Inbox Failed", message: "Error: \(error.localizedDescription)")
				} else if let inbox = inbox {
					print("✅ Fetch inbox (single topic: Promotions) successful:")
					print("   Total messages: \(inbox.countTotal)")
					print("   Unread messages: \(inbox.countUnread)")
					print("   Fetched messages: \(inbox.messages.count)")
					if let filteredTotal = inbox.countTotalFiltered {
						print("   Total filtered: \(filteredTotal)")
					}
					if let filteredUnread = inbox.countUnreadFiltered {
						print("   Unread filtered: \(filteredUnread)")
					}
					
					var message = "✅ Fetch inbox (Promotions) successful!\n\n"
					message += "Total messages: \(inbox.countTotal)\n"
					message += "Unread messages: \(inbox.countUnread)\n"
					message += "Fetched messages: \(inbox.messages.count)"
					
					if let filteredTotal = inbox.countTotalFiltered {
						message += "\nTotal filtered: \(filteredTotal)"
					}
					if let filteredUnread = inbox.countUnreadFiltered {
						message += "\nUnread filtered: \(filteredUnread)"
					}
					
					self.showAlert(title: "Fetch Inbox Success", message: message)
				}
			}
		}
	}

	@IBAction func fetchInboxMultiTopicsButtonClicked(_ sender: UIButton) {
		guard let externalUserId = currentExternalUserId else {
			showAlert(title: "No User ID", message: "Please personalize first to fetch inbox")
			return
		}
		let options = MMInboxFilterOptions(fromDateTime: nil, toDateTime: nil, topics: ["Transactions", "Personal"], limit: nil)
		MobileMessaging.inbox?.fetchInbox(externalUserId: externalUserId, options: options) { inbox, error in
			DispatchQueue.main.async {
				if let error = error {
					print("❌ Fetch inbox (multiple topics) failed: \(error.localizedDescription)")
					self.showAlert(title: "Fetch Inbox Failed", message: "Error: \(error.localizedDescription)")
				} else if let inbox = inbox {
					print("✅ Fetch inbox (multiple topics: Transactions, Personal) successful:")
					print("   Total messages: \(inbox.countTotal)")
					print("   Unread messages: \(inbox.countUnread)")
					print("   Fetched messages: \(inbox.messages.count)")
					if let filteredTotal = inbox.countTotalFiltered {
						print("   Total filtered: \(filteredTotal)")
					}
					if let filteredUnread = inbox.countUnreadFiltered {
						print("   Unread filtered: \(filteredUnread)")
					}
					
					var message = "✅ Fetch inbox (Transactions, Personal) successful!\n\n"
					message += "Total messages: \(inbox.countTotal)\n"
					message += "Unread messages: \(inbox.countUnread)\n"
					message += "Fetched messages: \(inbox.messages.count)"
					
					if let filteredTotal = inbox.countTotalFiltered {
						message += "\nTotal filtered: \(filteredTotal)"
					}
					if let filteredUnread = inbox.countUnreadFiltered {
						message += "\nUnread filtered: \(filteredUnread)"
					}
					
					self.showAlert(title: "Fetch Inbox Success", message: message)
				}
			}
		}
	}

	//MARK: Private
	fileprivate func validateFormat(_ msisdn : String) throws {
		let predicate = NSPredicate(format: "SELF MATCHES[cd] %@", SettingsViewController.kMSISDNValidationRegExp)
		predicate.evaluate(with: msisdn)
		if !predicate.evaluate(with: msisdn) {
			throw NSError(type: CustomErrorType.invalidMSISDNFormat)
		}
	}

	fileprivate func showActivityIndicator() {
		enableControls(false)
		activityIndicator.startAnimating()
		UIView.animate(withDuration: 0.1, delay: 0, options: [],
			animations: {
				self.setControlsAlpha(0.2)
			}) { (finished) -> Void in
				self.setControlsAlpha(0.2)
		}
	}

	fileprivate func hideActivityIndicator(_ completion: @escaping () -> Void) {
		activityIndicator.stopAnimating()
		UIView.animate(withDuration: 0.3, delay: 0.2, options: .beginFromCurrentState,
			animations: {
				self.setControlsAlpha(1)
			}) { (finished) -> Void in
				if (finished) {
					self.setControlsAlpha(1)
					self.enableControls(true)
					completion()
				}
		}
	}

	fileprivate func enableControls(_ enabled: Bool) {
		msisdsTextField.isEnabled = enabled
		sendMSISDNButton.isEnabled = enabled
		externalUserIdTextField.isEnabled = enabled
		personalizeButton.isEnabled = enabled
		depersonalizeButton.isEnabled = enabled
		fetchInboxAllButton.isEnabled = enabled
		fetchInboxSingleTopicButton.isEnabled = enabled
		fetchInboxMultiTopicsButton.isEnabled = enabled
		tabBarController?.tabBar.isUserInteractionEnabled = enabled
	}

	fileprivate func setControlsAlpha(_ alpha: CGFloat) {
		msisdsTextField.alpha = alpha
		sendMSISDNButton.alpha = alpha
		externalUserIdTextField.alpha = alpha
		personalizeButton.alpha = alpha
		depersonalizeButton.alpha = alpha
		fetchInboxAllButton.alpha = alpha
		fetchInboxSingleTopicButton.alpha = alpha
		fetchInboxMultiTopicsButton.alpha = alpha
	}

	fileprivate func showResultAlert(_ error: NSError?) {
		let cancelAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
		let alert = UIAlertController(title: error == nil ? "Success" : "Error",
		                              message: error == nil ? "MSISDN was successfully sent" : "\(error!.localizedDescription)",
		                              preferredStyle: .alert)
		alert.addAction(cancelAction)
		present(alert, animated: true, completion: nil)
	}

	fileprivate func showAlert(title: String, message: String) {
		let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
		present(alert, animated: true, completion: nil)
	}
	
	fileprivate func fetchUserAndUpdateUI() {
		MobileMessaging.fetchUser { user, error in
			DispatchQueue.main.async {
				if let user = user {
					self.currentExternalUserId = user.externalUserId
					if let externalUserId = user.externalUserId {
						self.externalUserIdTextField.text = externalUserId
						print("✅ User has externalUserId: \(externalUserId)")
					} else {
						print("ℹ️ User does not have externalUserId")
					}
				} else if let error = error {
					print("❌ Failed to fetch user: \(error.localizedDescription)")
				}
				self.updateUIForUserState()
			}
		}
	}
	
	fileprivate func updateUIForUserState() {
		let hasExternalUserId = currentExternalUserId != nil
		
		// If user has external ID, disable personalization controls
		externalUserIdTextField.isEnabled = !hasExternalUserId
		personalizeButton.isEnabled = !hasExternalUserId
		
		// Depersonalize button only enabled if user is personalized
		depersonalizeButton.isEnabled = hasExternalUserId
		
		// Inbox buttons only enabled if user has external ID
		fetchInboxAllButton.isEnabled = hasExternalUserId
		fetchInboxSingleTopicButton.isEnabled = hasExternalUserId
		fetchInboxMultiTopicsButton.isEnabled = hasExternalUserId
		
		// Update visual feedback
		let personalizeAlpha: CGFloat = hasExternalUserId ? 0.5 : 1.0
		let inboxAlpha: CGFloat = hasExternalUserId ? 1.0 : 0.5
		
		externalUserIdTextField.alpha = personalizeAlpha
		personalizeButton.alpha = personalizeAlpha
		depersonalizeButton.alpha = hasExternalUserId ? 1.0 : 0.5
		
		fetchInboxAllButton.alpha = inboxAlpha
		fetchInboxSingleTopicButton.alpha = inboxAlpha
		fetchInboxMultiTopicsButton.alpha = inboxAlpha
	}
}
