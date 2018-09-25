//
//  CPMessageDeliveryLabel.swift
//  Chatpay
//
//  Created by Andrey K. on 02.12.15.
//

import UIKit

class CPMessageDeliveryLabel: UILabel {
	static let deliveryStatusSpace:CGFloat = 12
	
	static let progressIndicatorRad:CGFloat = 5
	
	var message: ChatMessage? {
		didSet{
			if let msg = message {
				self.isYour = msg.isYours
				if self.isYour {
					self.deliveryStatus = msg.sentStatus.deliveryStatus
				}
				self.date = msg.composedDate
			}
		}
	}
	
	fileprivate var isYour: Bool = false {
		didSet {
			if isYour {
				self.textColor = UIColor.colorMod255(239, 135, 51).darker(25)
			} else {
				self.textColor = UIColor.gray
			}
		}
	}
	
	fileprivate lazy var checkmarksImageView : UIImageView = {
		let ret = UIImageView(image: UIImage(mm_named:"singleCheckmark"))
		ret.contentMode = .center
		ret.isHidden = true
		return ret
	}()

	fileprivate lazy var progressIndicator : CPProgressIndicationLayer = {
		let ret = CPProgressIndicationLayer(color: UIColor.ACTIVE_TINT(), width: 1, duration: 1)
		self.layer.addSublayer(ret)
		return ret
	}()

	fileprivate var deliveryStatus: CPMessageDeliveryStatus? {
		didSet {
			displayDeliveryStatus()
		}
	}
	
	fileprivate var date: Date? {
		didSet {
			if let date = date {
				text = date.timeString()
				displayDeliveryStatus()
			}
		}
	}
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		self.font = UIFont.systemFont(ofSize: 12)
		self.textAlignment = .left
		self.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
		self.addSubview(checkmarksImageView)
	}
	
	required init?(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}
	
	override func sizeThatFits(_ size: CGSize) -> CGSize {
		if let txt = text {
            let attrs = [NSAttributedString.fontAttributeName: font as Any]
            #if swift(>=4.0)
                var size = txt.size(withAttributes: attrs)
            #else
                var size = txt.size(attributes: attrs)
            #endif
			size.width += isYour ? CPMessageDeliveryLabel.deliveryStatusSpace : 0
			return size
		} else {
			return CGSize.zero
		}
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		if let deliveryStatus = deliveryStatus {
			let pendingStatuses:[CPMessageDeliveryStatus] = [.pendingSending, .pendingFileUploading]
			if pendingStatuses.contains(deliveryStatus) {
				let indicatorw = CPMessageDeliveryLabel.progressIndicatorRad*2
				progressIndicator.frame = bounds.inset(by: UIEdgeInsets(top: 0, left: self.cp_w - indicatorw, bottom: 0, right: 0))
				progressIndicator.frame.origin.x -= 3
			} else {
				let checkmarkw = CPMessageDeliveryLabel.deliveryStatusSpace
				checkmarksImageView.frame = bounds.inset(by: UIEdgeInsets(top: 0, left: self.cp_w - checkmarkw, bottom: 0, right: 0))
				progressIndicator.frame.origin.x -= 4
			}
		}
	}
	
	fileprivate func startProgressAnimation() {
		progressIndicator.isHidden = false
		progressIndicator.startAnimation()
	}
	
	fileprivate func stopProgressAnimation() {
		progressIndicator.stopAnimation()
		progressIndicator.isHidden = true
	}
	
	fileprivate func displayDeliveryStatus() {
		if let deliveryStatus = deliveryStatus {
			switch deliveryStatus {
			case .pendingSending, .pendingFileUploading:
				startProgressAnimation()
				checkmarksImageView.isHidden = true
			case .failed:
				stopProgressAnimation()
				checkmarksImageView.isHidden = false
				checkmarksImageView.image = UIImage(mm_named:"nondeliveredMessageIcon")
			case .sent:
				stopProgressAnimation()
				checkmarksImageView.isHidden = false
				checkmarksImageView.image = UIImage(mm_named:"singleCheckmark")
			case .delivered:
				stopProgressAnimation()
				checkmarksImageView.isHidden = false
				checkmarksImageView.image = UIImage(mm_named:"doubleCheckmark")
			}
		}
	}
}
