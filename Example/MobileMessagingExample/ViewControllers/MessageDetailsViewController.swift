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
			message?.removeObserver(self, forKeyPath: "delivered")
		}
		didSet {
			message?.addObserver(self, forKeyPath: "delivered", options: .New, context: nil)
			updateUI()
		}
	}
	
	override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
		if keyPath == "delivered" {
			updateUI()
		} else {
			super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
		}
	}
	
    override func viewDidLoad() {
        super.viewDidLoad()
		updateUI()
		seenMessage()
    }
    
    deinit {
		message?.removeObserver(self, forKeyPath: "delivered")
    }
    
    @IBAction func closeButtonClicked(sender: UIBarButtonItem) {
        self.dismissViewControllerAnimated(true, completion:nil)
    }
    
    //MARK: Private
    private func updateUI() {
		dispatch_async(dispatch_get_main_queue()) {
			if let msg = self.message {
				self.messageTextView?.text = msg.text
				self.deliveryStatus?.text = msg.delivered ? "Delivery report sent" : "Delivery report isn't sent"
				self.deliveryStatus?.textColor = msg.delivered ? UIColor.greenColor() : UIColor.redColor()
			}
		}
    }
	
	private func seenMessage() {
		guard let messageId = message?.messageId where message?.seen == false else {
			return
		}
		
		MobileMessaging.setSeen([messageId])
		message?.seen = true
	}

}
