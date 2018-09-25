//
//  CPBubbleCell.swift
//  Chatpay
//
//  Created by Andrey K. on 24.08.15.
//

import UIKit

enum CPOrderCellState {
	case done, downloading, uploading, retry, broken
}

protocol NetworkingTracker {
	var cellState: CPOrderCellState {get}
	func startUploading()
	func startDownloading()
}


struct Constants {
	static let bubbleMaxPadding: CGFloat = 90
	static let bubbleMinHeight: CGFloat = 60
	static let bubbleEdgeGapHeigh: CGFloat = 5
	static let bubbleEdgeGapWidth: CGFloat = 5
	static let bubbleCornerRad: CGFloat = 7
	static let margin: CGFloat = 10
	static let smallMargin: CGFloat = 6
	static let smallerMargin: CGFloat = 3
	static let dateLabelHeight: CGFloat = 13
}

class CPBubbleCell: CPTableViewCell {
	var cellState: CPOrderCellState = .done
	func startUploading() {
		
	}
	func startDownloading() {
		
	}
	
	var bubbleView: UIView!
	var alignment: NSTextAlignment!
	var deliveryLabel: CPMessageDeliveryLabel!
	deinit {
		NotificationCenter.default.removeObserver(self)
	}
	init(style: UITableViewCell.CellStyle, reuseIdentifier: String?, alignment: NSTextAlignment) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		self.alignment = alignment
		
		self.backgroundColor = UIColor.clear
		self.selectedColor = UIColor.clear
		
		bubbleView = UIView()
		bubbleView.layer.cornerRadius = Constants.bubbleCornerRad
        bubbleView.layer.shadowColor = UIColor.black.cgColor
        bubbleView.layer.shadowOpacity = 0.1
        bubbleView.layer.shadowOffset = CGSize(width: 0, height: 1)
        bubbleView.layer.shadowRadius = 2
		bubbleView.layer.shouldRasterize = true
		bubbleView.layer.rasterizationScale = UIScreen.main.scale
		var bubbleLeftMargin: CGFloat = 0
		var bubbleRightMargin: CGFloat = 0
		if (alignment == NSTextAlignment.right) {
			bubbleLeftMargin = Constants.bubbleMaxPadding
			bubbleRightMargin = Constants.bubbleEdgeGapWidth
		} else {
			bubbleLeftMargin = Constants.bubbleEdgeGapWidth
			bubbleRightMargin = Constants.bubbleMaxPadding
		}
		bubbleView.frame = contentView.bounds.inset(by: UIEdgeInsets(top: Constants.bubbleEdgeGapHeigh, left: bubbleLeftMargin, bottom: Constants.bubbleEdgeGapHeigh, right: bubbleRightMargin))
		bubbleView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		contentView.addSubview(bubbleView)
		
		deliveryLabel = CPBubbleCell.deliveryLabel
		deliveryLabel.frame.y = contentView.bounds.height - Constants.dateLabelHeight - Constants.bubbleEdgeGapHeigh - 2
		contentView.addSubview(deliveryLabel)
		
		self.customSetup()
	}
	
	override func setSelected(_ selected: Bool, animated: Bool) {
		let color = bubbleView.backgroundColor
		super.setSelected(selected, animated: animated)
		
		if(selected) {
			bubbleView.backgroundColor = color
		}
	}
	
	override func setHighlighted(_ highlighted: Bool, animated: Bool) {
		let color = bubbleView.backgroundColor
		super.setHighlighted(highlighted, animated: animated)
		
		if(highlighted) {
			bubbleView.backgroundColor = color
		}
	}
	
	class var deliveryLabel: CPMessageDeliveryLabel {
		get {
			return CPMessageDeliveryLabel()
		}
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		self.customLayout()
		contentView.bringSubviewToFront(deliveryLabel)
		CPBubbleCell.updateFrameForDateLabel(&deliveryLabel, bubbleViewFrame: bubbleView.frame, alignment: alignment, availableWidth: contentView.frame.width)
	}
	
	class func updateFrameForDateLabel(_ label: inout CPMessageDeliveryLabel!, bubbleViewFrame: CGRect, alignment: NSTextAlignment, availableWidth: CGFloat) {
		label.sizeToFit()
		label.frame.width += 5
		var x: CGFloat = 0
		if (alignment == NSTextAlignment.right) {
			x = availableWidth - label.frame.width - Constants.bubbleEdgeGapWidth - 2
		} else {
			x = bubbleViewFrame.maxX - label.frame.width - 2
		}
		label.frame.height = Constants.dateLabelHeight
		label.frame.x = x
	}
	
	func customSetup() {
		// override in sublcass
	}
	
	func customLayout() {
		// override in sublcass
	}
	
	class func height(_ message: ChatMessage, maxWidth: CGFloat) -> CGFloat {
		return 0 // override in sublcass
	}
}
