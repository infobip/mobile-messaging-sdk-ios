//
//  CPMessageCell.swift
//
//  Created by Andrey K. on 01.09.15.
//

import UIKit

extension Constants {
	static let textLineHeight: CGFloat = 17
	static let textToDateSpace: CGFloat = 25
	static let textTopMargin: CGFloat = 8
	static let textBottomMargin: CGFloat = 4
	static let buttonTextSpace: CGFloat = 8
	static let buttonMargin: CGFloat = 5
	static let buttonHeight: CGFloat = 44
	static let accessoryViewWidth: CGFloat = 40
}

let authorshipEnabled = true

class CPMessageCell: CPBubbleCell {
	var authorLabel: CPLabel?
	var messageLabel: CPLabel!
	var buttons = [String: CPButton]()
	var message: ChatMessage? {
		didSet {
			if let msg = message {
				deliveryLabel.message = msg
				bubbleView.backgroundColor = UIColor.CHAT_MESSAGE_COLOR(msg.isYours)
				messageLabel.text = msg.body
				authorLabel?.text = msg.author?.username
				contentView.alpha = msg.isSilent ? 0.3 : 1
				updateMessageActionButtons(message: message)
			}
		}
	}
	
	private func updateMessageActionButtons(message: ChatMessage?) {
		buttons.forEach { _, btn in
			btn.removeFromSuperview()
		}
		buttons.removeAll()
		guard let message = message, let categoryId = message.category, let actions = MobileMessaging.category(withId: categoryId)?.chatCompatibleActions else {
			return
		}
		actions.forEach { action in
			let newButton = CPMessageCell.newActionButton(title: action.title)
			newButton.tag = action.identifier.hashValue
			newButton.actionBlock = { _ in
				NotificationsInteractionService.sharedInstance?.handleAction(
					identifier: action.identifier,
					categoryId: categoryId,
					message: message.mt,
					notificationUserInfo: message.originalPayload as? [String: Any],
					responseInfo: nil,
					completionHandler: {}
				)
			}
			buttons[action.identifier] = newButton
			contentView.addSubview(newButton)
		}
	}
	
	override func customSetup() {
		messageLabel = CPMessageCell.textLabel
		contentView.addSubview(messageLabel)
		if authorshipEnabled {
			authorLabel = CPMessageCell.authorLabel
			contentView.addSubview(authorLabel!)
		}
	}
	
	class func shouldShowAuthor(_ message: ChatMessage) -> Bool {
		return authorshipEnabled && message.isYours == false
	}

	func highlightMessagesAsNotSeen(isViewVisible: Bool) {
		guard isViewVisible, let msg = message, msg.isYours == false else {
			return
		}

		if msg.isSeen == true {
			contentView.backgroundColor = UIColor.clear
		} else {
			contentView.backgroundColor = UIColor.MAIN()
			UIView.animate(withDuration: 3
				, delay: 0
				, options: UIView.AnimationOptions.allowUserInteraction
				, animations:
				{
					self.contentView.backgroundColor = UIColor.clear
				}
				, completion: nil)
		}
	}
	
	override func customLayout() {
		guard let msg = message else {
			return
		}
		
		/*
			
		ANYTHING YOU CHANGE BELOW, YOU MUST KEEP IN SYNC WITH `func heightMessage(_ msg: CPMessage, maxWidth: CGFloat) -> CGFloat`
		
		*/
		var availableTextSpaceW = contentView.frame.width - Constants.bubbleMaxPadding - 2*Constants.margin - 2*Constants.bubbleEdgeGapWidth
		if isEditing {
			availableTextSpaceW += Constants.accessoryViewWidth
		}
		messageLabel.frame.width = availableTextSpaceW - Constants.margin
		messageLabel.sizeToFit()
		
		deliveryLabel.sizeToFit()
		
		var authorWidth: CGFloat = 0
		if CPMessageCell.shouldShowAuthor(msg) {
			authorLabel?.sizeToFit()
			authorWidth = (authorLabel?.cp_w ?? 0) + Constants.margin*2
			if authorWidth > availableTextSpaceW - Constants.margin {
				authorWidth = availableTextSpaceW - Constants.margin
				authorLabel?.frame.width = authorWidth - Constants.margin*2
			}
		}

		let totalTextAndDateWith = messageLabel.frame.width + Constants.textToDateSpace + deliveryLabel.frame.width
		
		if buttons.isEmpty && totalTextAndDateWith <= availableTextSpaceW && messageLabel.cp_h <= Constants.textLineHeight { // compact height
			bubbleView.frame.width = max(totalTextAndDateWith, authorWidth)
			if (alignment == NSTextAlignment.right) {
				bubbleView.frame.x = contentView.frame.width - bubbleView.frame.width - Constants.bubbleEdgeGapWidth
				messageLabel.frame.x = bubbleView.frame.x + Constants.margin
			} else {
				bubbleView.frame.x = Constants.bubbleEdgeGapWidth
				messageLabel.frame.x = bubbleView.frame.x + Constants.margin
			}
		} else {
			bubbleView.frame.width = !buttons.isEmpty
				? availableTextSpaceW + Constants.margin
				: max(max(messageLabel.frame.width + Constants.margin*2, authorWidth), deliveryLabel.frame.width + Constants.margin*2)
			if (alignment == NSTextAlignment.right) {
				bubbleView.frame.x = contentView.frame.width - bubbleView.frame.width - Constants.bubbleEdgeGapWidth
				messageLabel.frame.x = bubbleView.frame.x + Constants.margin
			} else {
				bubbleView.frame.x = Constants.bubbleEdgeGapWidth
				messageLabel.frame.x = bubbleView.frame.x + Constants.margin
			}
		}
		
		if let authorLabel = authorLabel , CPMessageCell.shouldShowAuthor(msg) {
			authorLabel.frame.x = messageLabel.frame.x
			authorLabel.frame.y = Constants.margin
			messageLabel.frame.y = authorLabel.frame.maxY + Constants.smallerMargin
		} else {
			let textVertMargin = Constants.bubbleEdgeGapHeigh + Constants.textTopMargin
			messageLabel.frame.y = textVertMargin
		}
		
		for (i, kv) in buttons.enumerated() {
			let button = kv.value
			button.frame.y = messageLabel.frame.maxY + Constants.buttonTextSpace + CGFloat(i)*(Constants.buttonMargin + Constants.buttonHeight)
			button.frame.x = bubbleView.frame.x + Constants.margin
			button.frame.width = bubbleView.frame.width - Constants.margin * 2
		}
	}

	class func heightMessage(_ msg: ChatMessage, maxWidth: CGFloat) -> CGFloat {
		/*
		
		ANYTHING YOU CHANGE BELOW, YOU MUST KEEP IN SYNC WITH `func customLayout()`
		
		*/
		let availableTextWidthSpace = maxWidth - Constants.bubbleMaxPadding - 2*Constants.margin - 2*Constants.bubbleEdgeGapWidth
		
		let authorLabel: CPLabel? = CPMessageCell.shouldShowAuthor(msg) ? CPMessageCell.authorLabel : nil
		authorLabel?.frame.width = availableTextWidthSpace
		authorLabel?.text = msg.author?.username
		authorLabel?.sizeToFit()
		
		let messageLabel = CPMessageCell.textLabel
		messageLabel.frame.width = availableTextWidthSpace - Constants.margin
		messageLabel.text = msg.body
		messageLabel.sizeToFit()
		
		var deliveryLabel: CPMessageDeliveryLabel! = CPBubbleCell.deliveryLabel
		deliveryLabel.message = msg
		CPBubbleCell.updateFrameForDateLabel(&deliveryLabel, bubbleViewFrame: CGRect.zero, alignment: NSTextAlignment.right, availableWidth: maxWidth)
		let testWidth = messageLabel.frame.width + Constants.textToDateSpace + deliveryLabel.frame.width
		let buttonsHeight = msg.buttonsHeight
		
		let ret: CGFloat
		if buttonsHeight == 0 && testWidth < availableTextWidthSpace && messageLabel.cp_h <= Constants.textLineHeight { // compact height
			let textH = messageLabel.frame.height
			ret = textH + Constants.textTopMargin + Constants.textBottomMargin + Constants.bubbleEdgeGapHeigh * 2 + (authorLabel?.cp_h ?? 0)
		} else {
			let textH = messageLabel.frame.height
			ret = textH + Constants.textTopMargin + Constants.textBottomMargin + Constants.bubbleEdgeGapHeigh * 2 + deliveryLabel.frame.height + (authorLabel?.cp_h ?? 0) + buttonsHeight
		}
		return ret
	}

	override class func height(_ message: ChatMessage, maxWidth: CGFloat) -> CGFloat{
		return self.heightMessage(message, maxWidth: maxWidth)
	}
	
	class var textLabel: CPLabel {
		get{
			let result = CPLabel()
			result.font = UIFont.systemFont(ofSize: 15)
			result.numberOfLines = 0
			result.textColor = UIColor.TEXT_BLACK()
			result.maxLineHeight = Constants.textLineHeight
			
			return result
		}
	}

	class func newActionButton(title: String) -> CPButton {
		let btn = CPButton(type: .custom)
		btn.setTitle(title, for: .normal)
		btn.layer.borderWidth = 2.0
		btn.titleLabel?.numberOfLines = 1
		btn.layer.borderColor = UIColor.ACTIVE_TINT().cgColor
		btn.titleLabel?.font = UIFont.systemFont(ofSize: 18.0)
		btn.setTitleColor(UIColor.ACTIVE_TINT(), for: .normal)
		btn.layer.cornerRadius = 5
		btn.layer.rasterizationScale = UIScreen.main.scale
		btn.layer.shouldRasterize = true
		btn.frame.height = Constants.buttonHeight
		return btn
	}
	
	class var authorLabel: CPLabel {
		get{
			let result = CPLabel()
			result.font = UIFont.systemFont(ofSize: 13)
			result.numberOfLines = 1
			result.textColor = UIColor.TEXT_GRAY()
			result.maxLineHeight = 15
			
			return result
		}
	}
}

extension NotificationCategory {
	var chatCompatibleActions: [NotificationAction] {
		return actions.filter { (action) -> Bool in
			return action.options.contains(NotificationActionOptions.chatCompatible)
		}
	}
}

extension ChatMessage {
	var buttonsHeight: CGFloat {
		guard let categoryId = category, let actions = MobileMessaging.category(withId: categoryId)?.chatCompatibleActions else {
			return 0
		}
		return Constants.buttonTextSpace + CGFloat(actions.count) * (Constants.buttonHeight + Constants.buttonMargin)
	}
}
