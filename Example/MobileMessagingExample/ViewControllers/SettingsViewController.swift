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
	static let kMSISDNValidationRegExp = "^[0-9]{4,17}$"
	
	@IBOutlet weak var msisdsTextField: UITextField!
	@IBOutlet weak var activityIndicator: UIActivityIndicatorView!
	@IBOutlet weak var sendMSISDNButton: UIButton!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		msisdsTextField.delegate = self
		msisdsTextField.text = MobileMessaging.currentInstallation?.msisdn
	}
	
	//MARK: UITextFieldDelegate
	func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
		let cs = NSCharacterSet.decimalDigitCharacterSet()
		var currentText : NSString = msisdsTextField.text ?? ""
		currentText = currentText.stringByReplacingCharactersInRange(range, withString:string)
		currentText = currentText.componentsSeparatedByCharactersInSet(cs.invertedSet).joinWithSeparator("")
		msisdsTextField.text = currentText as String
		return false
	}

	//MARK: Actions
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
			hideActivityIndicator {
				self.showResultAlert(error)
			}
		}
	}
	
	//MARK: Private
	private func validateFormat(msisdn : String) throws {
		let predicate = NSPredicate(format: "SELF MATCHES[cd] %@", SettingsViewController.kMSISDNValidationRegExp)
		predicate.evaluateWithObject(msisdn)
		if !predicate.evaluateWithObject(msisdn) {
			throw NSError(type: CustomErrorType.InvalidMSISDNFormat)
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
		msisdsTextField.enabled = enabled
		sendMSISDNButton.enabled = enabled
		tabBarController?.tabBar.userInteractionEnabled = enabled
	}
	
	private func setControlsAlpha(alpha: CGFloat) {
		msisdsTextField.alpha = alpha
		sendMSISDNButton.alpha = alpha
	}
	
	private func showResultAlert(error: NSError?) {
		let cancelAction = UIAlertAction(title: "OK", style: .Cancel, handler: nil)
		let alert = UIAlertController(title: error == nil ? "Success" : "Error",
		                              message: error == nil ? "MSISDN was successfully sent" : "\(error!.localizedDescription)",
		                              preferredStyle: .Alert)
		alert.addAction(cancelAction)
		presentViewController(alert, animated: true, completion: nil)

	}
}
