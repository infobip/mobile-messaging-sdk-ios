//
//  SettingsViewController.swift
//  MobileMessagingExample
//
//  Created by okoroleva on 28.04.16.
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
		msisdsTextField.text = MobileMessaging.currentUser?.msisdn
	}
	
	//MARK: UITextFieldDelegate
	func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
		let cs = CharacterSet.decimalDigits
		let nsString : NSString = (msisdsTextField.text ?? "") as NSString
		var string = nsString.replacingCharacters(in: range, with: string)
		string = string.components(separatedBy: cs.inverted).joined(separator: "")
		msisdsTextField.text = string
		
		return false
	}

	//MARK: Actions
	@IBAction func sendMSISDNButtonClicked(_ sender: UIButton) {
		guard let msisdn = msisdsTextField.text else {
			return
		}
		
		showActivityIndicator()
		
		do {
			try validateFormat(msisdn)
			
			MobileMessaging.currentUser?.save(msisdn: msisdn, completion: { (error) -> () in
				DispatchQueue.main.async {
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
	fileprivate func validateFormat(_ msisdn : String) throws {
		let predicate = NSPredicate(format: "SELF MATCHES[cd] %@", SettingsViewController.kMSISDNValidationRegExp)
		predicate.evaluate(with: msisdn)
		if !predicate.evaluate(with: msisdn) {
			throw NSError(type: CustomErrorType.invalidMSISDNFormat)
		}
	}
	
	fileprivate func showActivityIndicator() {
		enableControls(false)
		activityIndicator.startAnimating()
		UIView.animate(withDuration: 0.1, delay: 0, options: [],
			animations: {
				self.setControlsAlpha(0.2)
			}) { (finished) -> Void in
				self.setControlsAlpha(0.2)
		}
	}
	
	fileprivate func hideActivityIndicator(_ completion: @escaping () -> Void) {
		activityIndicator.stopAnimating()
		UIView.animate(withDuration: 0.3, delay: 0.2, options: .beginFromCurrentState,
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
	
	fileprivate func enableControls(_ enabled: Bool) {
		msisdsTextField.isEnabled = enabled
		sendMSISDNButton.isEnabled = enabled
		tabBarController?.tabBar.isUserInteractionEnabled = enabled
	}
	
	fileprivate func setControlsAlpha(_ alpha: CGFloat) {
		msisdsTextField.alpha = alpha
		sendMSISDNButton.alpha = alpha
	}
	
	fileprivate func showResultAlert(_ error: NSError?) {
		let cancelAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
		let alert = UIAlertController(title: error == nil ? "Success" : "Error",
		                              message: error == nil ? "MSISDN was successfully sent" : "\(error!.localizedDescription)",
		                              preferredStyle: .alert)
		alert.addAction(cancelAction)
		present(alert, animated: true, completion: nil)

	}
}
