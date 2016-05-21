//
//  MessageDetailsViewController.swift
//  MobileMessaging
//
//  Created by okoroleva on 31.03.16.
//

import UIKit
import MobileMessaging

class MessageDetailsViewController: UIViewController {
    
    @IBOutlet weak var deliveryStatus: UILabel?
    @IBOutlet weak var messageTextView: UITextView?
	
	var message: Message? {
		willSet {
			resetMessageObserving()
		}
		didSet {
			message?.addObserver(self, forKeyPath: kMessageDeliveryReportSentAttribute, options: .New, context: nil)
			updateUI()
		}
	}
	
	override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
		if keyPath == kMessageDeliveryReportSentAttribute {
			updateUI()
		} else {
			super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
		}
	}
	
    override func viewDidLoad() {
        super.viewDidLoad()
		updateUI()
    }
	
	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)
		markMessageAsSeen()
	}
    
    deinit {
		resetMessageObserving()
    }
    
    @IBAction func closeButtonClicked(sender: UIBarButtonItem) {
        self.dismissViewControllerAnimated(true, completion:nil)
    }
    
    //MARK: Private
    private func updateUI() {
		dispatch_async(dispatch_get_main_queue()) {
			if let msg = self.message {
				self.messageTextView?.text = msg.text
				self.deliveryStatus?.text = msg.deliveryReportSent ? "Delivery report sent" : "Delivery report not sent"
				self.deliveryStatus?.textColor = msg.deliveryReportSent ? UIColor.greenColor() : UIColor.redColor()
			}
		}
    }
	
	private func resetMessageObserving() {
		message?.removeObserver(self, forKeyPath: kMessageDeliveryReportSentAttribute)
	}
	
	private func markMessageAsSeen() {
		guard let messageId = message?.messageId where message?.seen == false else {
			return
		}
		
		MobileMessaging.setSeen([messageId])
		message?.seen = true
	}

}
