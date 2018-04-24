//
//  ViewController.swift
//  MobileChatExample
//
//  Created by Andrey Kadochnikov on 10/11/2017.
//  Copyright © 2017 Infobip d.o.o. All rights reserved.
//

import UIKit
import MobileMessaging

class ViewController: UITableViewController, ChatMessagesControllerDelegate {
	static let reuseIdentifierToDoCell = "messageCell"
	var chatMessagesController: ChatMessagesController!
	
	@IBAction func composeMessage(_ sender: Any) {
		let alertController = UIAlertController.makeComposingAlert(sendActionBlock: { text in
			MobileMessaging.mobileChat?.send(chatId: nil, text: text, completion: nil)
		})
		present(alertController, animated: true, completion: nil)
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		// chatMessagesController setup
		chatMessagesController = MobileMessaging.mobileChat?.chatMessagesController
		chatMessagesController.delegate = self
		chatMessagesController.performFetch()
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
        let messagesCount = chatMessagesController.fetchedMessagesCount
        if messagesCount > 0 {
            self.tableView.scrollToRow(at: IndexPath(row: messagesCount - 1, section: 0), at: .bottom, animated: false)
        }
	}
	
//MARK: - ChatMessagesControllerDelegate implementation
	func controllerWillChangeContent(_ controller: ChatMessagesController) { }
	
	func controller(_ controller: ChatMessagesController, didChange message: ChatMessage, at indexPath: IndexPath?, for type: ChatMessagesChangeType, newIndexPath: IndexPath?) {
		switch (type) {
		case .insert:
			if let indexPath = newIndexPath {
				self.tableView.insertRows(at: [indexPath], with: .none)
				self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
			}
		case .delete:
			if let indexPath = indexPath {
				self.tableView.deleteRows(at: [indexPath], with: .automatic)
			}
		case .update:
			if let indexPath = indexPath {
				if let cell = self.tableView.cellForRow(at: indexPath) {
					configureCell(cell, atIndexPath: indexPath)
				}
			}
		case .move:
			if let indexPath = indexPath {
				self.tableView.deleteRows(at: [indexPath], with: .automatic)
			}
			
			if let newIndexPath = newIndexPath {
				self.tableView.insertRows(at: [newIndexPath], with: .automatic)
			}
		}
	}
	
	func controllerDidChangeContent(_ controller: ChatMessagesController) { }
	
//MARK: - UITableViewDataSource
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return chatMessagesController.fetchedMessagesCount
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: ViewController.reuseIdentifierToDoCell, for: indexPath)
		configureCell(cell, atIndexPath: indexPath)
		return cell
	}

//MARK: - Helpers
	private func configureCell(_ cell: UITableViewCell, atIndexPath indexPath: IndexPath) {
		guard let chatMessage = chatMessagesController.chatMessage(at: indexPath) else {
			return
		}
		if chatMessage.isYours {
			cell.textLabel?.textAlignment = .right
		} else {
			cell.textLabel?.textAlignment = .left
		}
		cell.textLabel?.attributedText = NSAttributedString.makeChatMessageText(with: chatMessage)
	}
}
