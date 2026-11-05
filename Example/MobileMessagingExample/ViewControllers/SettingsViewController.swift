// 
//  Example/MobileMessagingExample/ViewControllers/SettingsViewController.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
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
	@IBOutlet weak var fetchInboxNextPageButton: UIButton!
	@IBOutlet weak var deleteInboxMessageButton: UIButton!
	@IBOutlet weak var testInboxPaginationButton: UIButton!
	
	private var currentExternalUserId: String?
	/// Messages fetched by the "All" and "Next Page" buttons, and the cursor for the next page.
	private var fetchedInboxMessages: [MM_MTMessage] = []
	private var inboxNextCursor: String?
	/// True once a paged fetch returned no `nextCursor`, i.e. there are no more pages until paging is reset.
	private var inboxPagingFinished = false
	private static let inboxPageSize = 5

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
						self.resetInboxPaging()
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
						self.resetInboxPaging()
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

	@IBAction func fetchInboxAllButtonClicked(_ sender: UIButton) {
		resetInboxPaging()
		fetchInboxPage(options: MMInboxFilterOptions(fromDateTime: nil, toDateTime: nil, topic: nil, limit: 100), title: "All - limit 100")
	}

	@IBAction func fetchInboxNextPageButtonClicked(_ sender: UIButton) {
		// First tap fetches the first page, every next tap continues with the cursor returned by the previous page.
		// The cursor must be used with the same topic and date filters as the page it was returned with.
		let isFirstPage = inboxNextCursor == nil
		if isFirstPage {
			fetchedInboxMessages = []
		}
		let options = MMInboxFilterOptions(fromDateTime: nil, toDateTime: nil, topic: nil, limit: SettingsViewController.inboxPageSize, cursor: inboxNextCursor)
		fetchInboxPage(options: options, title: isFirstPage ? "first page" : "next page", paged: true)
	}

	@IBAction func deleteFirstInboxMessageButtonClicked(_ sender: UIButton) {
		guard let externalUserId = currentExternalUserId else {
			showAlert(title: "No User ID", message: "Please personalize first to delete inbox messages")
			return
		}
		guard let message = fetchedInboxMessages.first else {
			showAlert(title: "Nothing To Delete", message: "Fetch inbox messages first (\"All\" or \"page size 5\")")
			return
		}
		// Optional chaining on a nil inbox service would silently skip the delete, so check it explicitly.
		guard let inbox = MobileMessaging.inbox else {
			showAlert(title: "Delete Failed", message: "Mobile Messaging SDK is not started")
			return
		}
		showActivityIndicator()
		// Uses Application Code authorization like the other inbox buttons on this screen.
		// In production use deleteMessages(token:externalUserId:messageIds:) with the same JWT used for fetching the inbox.
		Task { @MainActor in
			do {
				try await inbox.deleteMessages(externalUserId: externalUserId, messageIds: [message.messageId])
				self.hideActivityIndicator {
					print("✅ Deleted inbox message \(message.messageId)")
					self.fetchedInboxMessages.removeAll { $0.messageId == message.messageId }
					self.showAlert(title: "Delete Success", message: "Deleted message:\n\(message.messageId)\n\(message.text ?? "")\n\nA fetch right after deleting may still briefly return it (eventual consistency).")
				}
			} catch {
				self.hideActivityIndicator {
					print("❌ Delete inbox message \(message.messageId) failed: \(error)")
					self.showAlert(title: "Delete Failed", message: self.describe(error as NSError))
				}
			}
		}
	}

	/// Debug self-test: fetches the whole inbox in one request (limit 100), then walks it page by page following `nextCursor`
	/// (without topic filter and with topic "Promotions") and verifies that paging returns exactly the same messages, in the same order.
	/// Meaningful only for inboxes with at most 100 messages and while no new messages arrive during the test.
	@IBAction func testInboxPaginationButtonClicked(_ sender: UIButton) {
		guard let externalUserId = currentExternalUserId, let inbox = MobileMessaging.inbox else {
			showAlert(title: "No User ID", message: "Please personalize first to test pagination")
			return
		}
		showActivityIndicator()
		Task { @MainActor in
			var report: [String] = []
			var passed = true
			func check(_ name: String, _ condition: Bool, _ detail: String = "") {
				passed = passed && condition
				report.append("\(condition ? "✅" : "❌") \(name)\(detail.isEmpty ? "" : " (\(detail))")")
			}
			func walk(topic: String?, pageSize: Int) async throws -> (ids: [String], pages: Int, last: MMInbox?) {
				var ids: [String] = []
				var pages = 0
				var cursor: String? = nil
				var last: MMInbox? = nil
				repeat {
					let options = MMInboxFilterOptions(fromDateTime: nil, toDateTime: nil, topic: topic, limit: pageSize, cursor: cursor)
					last = try await inbox.fetchInbox(externalUserId: externalUserId, options: options)
					pages += 1
					ids += last?.messages.map { $0.messageId } ?? []
					cursor = last?.nextCursor
				} while cursor != nil && pages < 50
				return (ids, pages, last)
			}
			do {
				for topic in [nil, "Promotions"] as [String?] {
					let label = topic ?? "all topics"
					let full = try await inbox.fetchInbox(externalUserId: externalUserId, options: MMInboxFilterOptions(fromDateTime: nil, toDateTime: nil, topic: topic, limit: 100))
					let expected = full?.messages.map { $0.messageId } ?? []
					let paged = try await walk(topic: topic, pageSize: SettingsViewController.inboxPageSize)
					report.append("\n[\(label)] \(expected.count) messages, page size \(SettingsViewController.inboxPageSize)")
					check("pages", paged.pages == max(1, Int(ceil(Double(expected.count) / Double(SettingsViewController.inboxPageSize)))), "\(paged.pages)")
					check("same messages, same order", paged.ids == expected, "\(paged.ids.count) paged / \(Set(paged.ids).count) unique")
					check("last page has no nextCursor", paged.last?.nextCursor == nil)
					check("counters don't depend on cursor", paged.last?.countTotal == full?.countTotal && paged.last?.countTotalFiltered == full?.countTotalFiltered, "total \(paged.last?.countTotal ?? -1), filtered \(paged.last?.countTotalFiltered.map(String.init) ?? "nil")")
				}
				// A cursor is bound to the filters it was returned with
				let firstPage = try await inbox.fetchInbox(externalUserId: externalUserId, options: MMInboxFilterOptions(fromDateTime: nil, toDateTime: nil, topic: nil, limit: SettingsViewController.inboxPageSize))
				if let cursor = firstPage?.nextCursor {
					do {
						_ = try await inbox.fetchInbox(externalUserId: externalUserId, options: MMInboxFilterOptions(fromDateTime: nil, toDateTime: nil, topic: "Promotions", limit: SettingsViewController.inboxPageSize, cursor: cursor))
						check("cursor with other topic rejected", false, "no error")
					} catch {
						check("cursor with other topic rejected", (error as NSError).mm_code == "INVALID_CURSOR", (error as NSError).mm_code ?? "\(error)")
					}
				}
			} catch {
				check("requests succeeded", false, describe(error as NSError))
			}
			hideActivityIndicator {
				let summary = report.joined(separator: "\n")
				print("Inbox pagination test:\n\(summary)")
				self.showAlert(title: passed ? "Pagination Test Passed" : "Pagination Test Failed", message: summary)
			}
		}
	}

	fileprivate func resetInboxPaging() {
		fetchedInboxMessages = []
		inboxNextCursor = nil
		inboxPagingFinished = false
		updateNextPageButton()
	}

	/// "page size 5" before paging starts, "next page" while a cursor is available, greyed out after the last page.
	fileprivate func updateNextPageButton() {
		let title: String
		if inboxPagingFinished {
			title = "Fetch Inbox (no more pages)"
		} else if inboxNextCursor != nil {
			title = "Fetch Inbox (next page)"
		} else {
			title = "Fetch Inbox (page size \(SettingsViewController.inboxPageSize))"
		}
		UIView.performWithoutAnimation {
			fetchInboxNextPageButton.setTitle(title, for: .normal)
			fetchInboxNextPageButton.layoutIfNeeded()
		}
		let enabled = currentExternalUserId != nil && !inboxPagingFinished
		fetchInboxNextPageButton.isEnabled = enabled
		fetchInboxNextPageButton.alpha = enabled ? 1.0 : 0.5
	}

	fileprivate func fetchInboxPage(options: MMInboxFilterOptions, title: String, paged: Bool = false) {
		guard let externalUserId = currentExternalUserId else {
			showAlert(title: "No User ID", message: "Please personalize first to fetch inbox")
			return
		}
		guard let inboxService = MobileMessaging.inbox else {
			showAlert(title: "Fetch Inbox Failed", message: "Mobile Messaging SDK is not started")
			return
		}
		showActivityIndicator()
		inboxService.fetchInbox(externalUserId: externalUserId, options: options) { inbox, error in
			DispatchQueue.main.async {
				self.hideActivityIndicator {
					if let error = error {
						print("❌ Fetch inbox (\(title)) failed: \(error)")
						self.showAlert(title: "Fetch Inbox Failed", message: self.describe(error))
						return
					}
					guard let inbox = inbox else {
						return
					}
					self.fetchedInboxMessages += inbox.messages
					self.inboxNextCursor = inbox.nextCursor
					self.inboxPagingFinished = paged && inbox.nextCursor == nil
					self.updateNextPageButton()
					
					var message = "Total messages: \(inbox.countTotal)\n"
					message += "Unread messages: \(inbox.countUnread)\n"
					message += "Fetched in this page: \(inbox.messages.count)\n"
					message += "Fetched so far: \(self.fetchedInboxMessages.count)\n"
					message += "nextCursor: \(inbox.nextCursor ?? "nil (no more pages)")"
					if !inbox.messages.isEmpty {
						message += "\n\n" + inbox.messages.map { "• [\($0.topic ?? "-")] \($0.text ?? "")" }.joined(separator: "\n")
					}
					print("✅ Fetch inbox (\(title)) successful:\n\(message)")
					self.showAlert(title: "Fetch Inbox (\(title))", message: message)
				}
			}
		}
	}

	fileprivate func describe(_ error: NSError) -> String {
		var description = "Error: \(error.localizedDescription)"
		if let code = error.mm_code {
			description += "\nCode: \(code)"
		}
		description += "\nDomain: \(error.domain) (\(error.code))"
		return description
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
					self.updateNextPageButton()
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
		fetchInboxNextPageButton.isEnabled = enabled
		deleteInboxMessageButton.isEnabled = enabled
		testInboxPaginationButton.isEnabled = enabled
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
		fetchInboxNextPageButton.alpha = alpha
		deleteInboxMessageButton.alpha = alpha
		testInboxPaginationButton.alpha = alpha
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
		deleteInboxMessageButton.isEnabled = hasExternalUserId
		testInboxPaginationButton.isEnabled = hasExternalUserId
		
		// Update visual feedback
		let personalizeAlpha: CGFloat = hasExternalUserId ? 0.5 : 1.0
		let inboxAlpha: CGFloat = hasExternalUserId ? 1.0 : 0.5
		
		externalUserIdTextField.alpha = personalizeAlpha
		personalizeButton.alpha = personalizeAlpha
		depersonalizeButton.alpha = hasExternalUserId ? 1.0 : 0.5
		
		fetchInboxAllButton.alpha = inboxAlpha
		fetchInboxSingleTopicButton.alpha = inboxAlpha
		fetchInboxMultiTopicsButton.alpha = inboxAlpha
		deleteInboxMessageButton.alpha = inboxAlpha
		testInboxPaginationButton.alpha = inboxAlpha
		updateNextPageButton()
	}
}
