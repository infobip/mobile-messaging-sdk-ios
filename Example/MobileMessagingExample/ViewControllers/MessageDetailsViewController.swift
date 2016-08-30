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
			message?.addObserver(self, forKeyPath: kMessageDeliveryReportSentAttribute, options: .new, context: nil)
			updateUI()
		}
	}
	
	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		if keyPath == kMessageDeliveryReportSentAttribute {
			updateUI()
		} else {
			super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
		}
	}
	
    override func viewDidLoad() {
        super.viewDidLoad()
		updateUI()
    }
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		markMessageAsSeen()
	}
    
    deinit {
		resetMessageObserving()
    }
    
    @IBAction func closeButtonClicked(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion:nil)
    }
    
    //MARK: Private
    private func updateUI() {
		DispatchQueue.main.async {
			if let msg = self.message {
				self.messageTextView?.text = msg.text
				self.deliveryStatus?.text = msg.deliveryReportSent ? "Delivery report sent" : "Delivery report not sent"
				self.deliveryStatus?.textColor = msg.deliveryReportSent ? UIColor.green : UIColor.red
			}
		}
    }
	
	private func resetMessageObserving() {
		message?.removeObserver(self, forKeyPath: kMessageDeliveryReportSentAttribute)
	}
	
	private func markMessageAsSeen() {
		guard let messageId = message?.messageId , message?.seen == false else {
			return
		}
		
		MobileMessaging.setSeen(messageIds: [messageId])
		message?.seen = true
	}

}
