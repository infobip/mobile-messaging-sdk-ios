//
//  SettingsViewController.swift
//  MobileMessagingExample
//
//  Created by okoroleva on 28.04.16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit
import MobileMessaging

class SettingsViewController : UIViewController, UITextFieldDelegate {
	@IBOutlet weak var msisdsTextField: UITextField!
	@IBOutlet weak var activityIndicator: UIActivityIndicatorView!
	@IBOutlet weak var sendMSISDNButton: UIButton!
	@IBOutlet weak var closeBarButtonItem: UIBarButtonItem!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		msisdsTextField.delegate = self
	}
	
	//MARK: UITextFieldDelegate
	func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
		let cs = NSCharacterSet.decimalDigitCharacterSet()
		var currentText : NSString = self.msisdsTextField.text ?? ""
		currentText = currentText.stringByReplacingCharactersInRange(range, withString:string)
		currentText = currentText.componentsSeparatedByCharactersInSet(cs.invertedSet).joinWithSeparator("")
		self.msisdsTextField.text = currentText as String
		return false
	}

	//MARK: Actions
	@IBAction func closeButtonPressed(sender: UIBarButtonItem) {
		dismissViewControllerAnimated(true, completion:nil)
	}
	
	@IBAction func sendMSISDNButtonClicked(sender: UIButton) {
		guard let msisdn = msisdsTextField.text else {
			return
		}
		
		showActivityIndicator()
		
		do {
			try validateFormat(msisdn)
			
			MobileMessaging.currentInstallation?.saveMSISDN(msisdn, completion: { (error) -> () in
				dispatch_async(dispatch_get_main_queue()) {
					self.hideActivityIndicator {
						self.showResultAlert(error)
					}
				}
			})
			
		} catch let error as NSError {
			self.hideActivityIndicator {
				self.showResultAlert(error)
			}
		}
	}
	
	//MARK: Private
	private func validateFormat(msisdn : String) throws {
		let pattern = "^[1-9]{1}[0-9]{3,14}$"
		let predicate = NSPredicate(format: "SELF MATCHES[cd] %@", pattern)
		predicate.evaluateWithObject(msisdn)
		if !predicate.evaluateWithObject(msisdn) {
			throw NSError(domain: "custom", code: 100, userInfo: [
				NSLocalizedDescriptionKey :  NSLocalizedString("MSISDN format not valid", comment: ""),
				])
		}
	}
	
	private func showActivityIndicator() {
		enableControls(false)
		activityIndicator.startAnimating()
		UIView.animateWithDuration(0.1, delay: 0, options: [],
			animations: {
				self.setControlsAlpha(0.2)
			}) { (finished) -> Void in
				self.setControlsAlpha(0.2)
		}
	}
	
	private func hideActivityIndicator(completion: () -> Void) {
		activityIndicator.stopAnimating()
		UIView.animateWithDuration(0.3, delay: 0.2, options: .BeginFromCurrentState,
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
	
	private func enableControls(enabled: Bool) {
		self.msisdsTextField.enabled = enabled
		self.sendMSISDNButton.enabled = enabled
		self.closeBarButtonItem.enabled = enabled
	}
	
	private func setControlsAlpha(alpha: CGFloat) {
		self.msisdsTextField.alpha = alpha
		self.sendMSISDNButton.alpha = alpha
	}
	
	private func showResultAlert(error: NSError?) {
		let cancelAction = UIAlertAction(title: "OK", style: .Cancel, handler: nil)
  	    let alert = UIAlertController(title: error == nil ? "Success" : "Error occured",
			                        message: error == nil ? "MSISDN was successfully sent" : "\(error!.localizedDescription)",
			                        preferredStyle: .Alert)
		alert.addAction(cancelAction)
		presentViewController(alert, animated: true, completion: nil)

	}
}
