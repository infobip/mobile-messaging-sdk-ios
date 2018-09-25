//
//  CPChatDataSource.swift
//  Chatpay
//
//  Created by Andrey K. on 10.09.15.
//

import Foundation

//MARK: UITableViewDataSource, UITableViewDelegate
extension CPChatVC {
	
	func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
		return 0.001
	}
	
	func numberOfSectionsInTableView(_ tableView: UITableView) -> Int {
		return 1
	}
	
	override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return chatMessagesController?.fetchedMessagesCount ?? 0
	}
	
	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		guard let message = chatMessagesController?.chatMessage(at: indexPath) else {
			return 0
		}
		return CPMessageCell.heightMessage(message, maxWidth: tableView.bounds.width)
	}
	
	func tableView(_ tableView: UITableView, didSelectRowAtIndexPath indexPath: IndexPath) {
		if tableView.isEditing {
			guard let message = (tableView.cellForRow(at: indexPath) as? CPMessageCell)?.message else {
				return
			}
			selectedMessages.insert(SelectedMessageMeta(message))
			updateEditingModeButtons()
		} else {
			composeBarView.resignFirstResponder()
			tableView.deselectRow(at: indexPath, animated: true)
		}
	}
	
	func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
		if tableView.isEditing {
			guard let message = (tableView.cellForRow(at: indexPath) as? CPMessageCell)?.message else {
				return
			}
			selectedMessages.remove(SelectedMessageMeta(message))
			updateEditingModeButtons()
		}
	}
	
	override public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		guard let message = chatMessagesController?.chatMessage(at: indexPath) else {
			return UITableViewCell()
		}
		let cell = cellForMessage(message)
		configureCell(cell, atIndexPath: indexPath, withExplicitMessage: message)
		return cell
	}
	
	func cellForMessage(_ message: ChatMessage) -> CPMessageCell {
		let cellID: String
		let align: NSTextAlignment
		if (message.isYours) {
			cellID = "AuhtorMessageCell"
			align = NSTextAlignment.right
		} else {
			cellID = "MessageCell"
			align = NSTextAlignment.left
		}
		if let cell = tableView.dequeueReusableCell(withIdentifier: cellID) as? CPMessageCell {
			return cell
		} else {
			return CPMessageCell(style: UITableViewCell.CellStyle.default, reuseIdentifier: cellID, alignment: align)
		}
	}
}

