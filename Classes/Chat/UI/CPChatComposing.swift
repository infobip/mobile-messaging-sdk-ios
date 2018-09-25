//
//  CPChatComposing.swift
//
//  Created by Andrey Kadochnikov on 10.09.15.
//
import Foundation

extension CPChatVC {
	func setupComposerBar() {
		let viewBounds = view.bounds
		let frame = CGRect(x: 0,
						   y: viewBounds.size.height - ComposeBarConsts.initialHeight,
						   width: viewBounds.size.width,
						   height: ComposeBarConsts.initialHeight)
		composeBarView = ComposeBar(frame: frame)
		composeBarView.maxLinesCount = 5
		composeBarView.placeholder = "Message"
		composeBarView.delegate = composeBarDelegate
		composeBarView.alpha = 1
		view.addSubview(composeBarView)
		
		tableView.frame = view.bounds.inset(by: UIEdgeInsets(top: 0, left: 0, bottom: composeBarView.cp_h, right: 0))
	}
	
	func createTextMessage(_ text: String) {
		if MobileMessaging.mobileChat?.getUserInfo()?.id != nil {
			askUsernameIfNeeded { [weak self] _ in
				MobileMessaging.mobileChat?.send(chatId: nil, text: text, completion: { (_, error) in
					if isDebug, let error = error as NSError?, error.code == 14 {
						self?.showAlert(error)
					}
				})
			}
		}
	}
	
	func askUsernameIfNeeded(_ completion: @escaping (String?) -> Void) {
		guard let chatService = MobileMessaging.mobileChat, let chatUserInfo = chatService.getUserInfo() else
		{
			completion(nil)
			return
		}
		
		guard chatService.settings.isUsernameRequired else
		{
			completion(chatUserInfo.username)
			return
		}
		
		if let username = chatUserInfo.username, !username.isEmpty {
			completion(username)
		} else {
			let alertController = UIAlertController(title: "Welcome!", message: "Please enter your first name", preferredStyle: UIAlertController.Style.alert)
			let signAction = UIAlertAction(title: "OK", style: .default) { (_) in
				let nameTF = alertController.textFields![0] as UITextField
				if let firstName = nameTF.text {
					completion(firstName)
					chatUserInfo.firstName = firstName
					chatService.setUserInfo(info: chatUserInfo, completion: { (error) in
						if let error = error {
							self.showAlert(error)
						}
					})
				}
			}
			signAction.isEnabled = false
			
			alertController.addTextField { (textField) in
				textField.placeholder = "Your first name"
				textField.autocapitalizationType = .words
				NotificationCenter.default.addObserver(forName: UITextField.textDidChangeNotification, object: textField, queue: OperationQueue.main) { (notification) in
					signAction.isEnabled = textField.text != ""
				}
			}
			
			alertController.addAction(signAction)
			present(alertController, animated: true, completion: nil)
		}
	}
}

//MARK: Compose bar
class CPComposeBarDelegate: NSObject, ComposeBarDelegate {
	weak var tableView: UITableView?
	let makeMessageBlock: (String) -> Void
	
	init(tableView: UITableView, makeMessageBlock: @escaping (String) -> Void) {
		self.tableView = tableView
		self.makeMessageBlock = makeMessageBlock
	}
	
	public func composeBarDidPressButton(composeBar: ComposeBar) {
		makeMessageBlock(composeBar.text)
		composeBar.text = ""
	}
	
	public func composeBarDidPressUtilityButton(composeBar: ComposeBar) {
		_ = composeBar.resignFirstResponder()
	}
	
	func composeBar(composeBar: ComposeBar, willChangeFromFrame startFrame: CGRect, toFrame endFrame: CGRect, duration: TimeInterval, animationCurve: UIView.AnimationCurve) {
		let heightDelta = startFrame.height - endFrame.height
		
		self.tableView?.contentInset.top -= heightDelta
		self.tableView?.frame.y += heightDelta
	}
	
	func composeBarTextViewDidBeginEditing(composeBar: ComposeBar) {}
	func composeBarTextViewDidChange(composeBar: ComposeBar) {}
	func composeBar(composeBar: ComposeBar, didChangeFromFrame startFrame: CGRect, toFrame endFrame: CGRect) {}
}

