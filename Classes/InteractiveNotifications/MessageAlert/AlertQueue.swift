//
//  AlertQueue.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 26/04/2018.
//

import Foundation

class AlertOperation: Foundation.Operation {
	let group = DispatchGroup()
	var alert: InteractiveMessageAlertController?
	let message: MTMessage
	let text: String
	
	init(with message: MTMessage, text: String) {
		self.message = message
		self.text = text
		super.init()
		self.addObserver(self, forKeyPath: "isCancelled", options: NSKeyValueObservingOptions.new, context: nil)
	}
	
	deinit {
		self.removeObserver(self, forKeyPath: "isCancelled")
	}
	
	override func main() {
		if isCancelled {
			return
		}
		group.enter()
		
		DispatchQueue.main.async() {
			if self.message.contentUrl?.safeUrl != nil {
				self.message.downloadImageAttachment(completion: { (url, error) in
					let img: Image?
					if let url = url, let data = try? Data(contentsOf: url) {
						img = DefaultImageProcessor().process(item: ImageProcessItem.data(data), options: [])
					} else {
						img = nil
					}
					self.alert = self.displayAlert(with: self.message, image: img, text: self.text)
					self.presentAlert()
				})
			} else {
				self.alert = self.displayAlert(with: self.message, image: nil, text: self.text)
				self.presentAlert()
			}
		}
		
		group.wait()
	}
	
	func presentAlert() {
		guard let alert = self.alert, !self.isCancelled else { return }
		UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
	}
	
	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		if keyPath == "isCancelled" {
			if (change?[NSKeyValueChangeKey.newKey] as? Bool ?? false) == true {
				self.alert?.dismiss(animated: false)
				self.group.leave()
			}
		} else {
			return
		}
	}
	
	private func displayAlert(with message: MTMessage, image: Image?, text: String) -> InteractiveMessageAlertController {
		let alert : InteractiveMessageAlertController
		
		if let categoryId = message.category, let category = MobileMessaging.category(withId: categoryId), category.actions.first(where: { return $0 is TextInputNotificationAction } ) == nil {
			alert = InteractiveMessageAlertController(
				titleText: message.title,
				messageText: text,
				imageURL: nil,
				image: image,
				category: category,
				actionHandler: {
					action in
					MobileMessaging.handleAction(
						identifier: action.identifier,
						category: categoryId,
						message: message,
						notificationUserInfo: message.originalPayload,
						responseInfo: nil,
						completionHandler: {}
					)
			})
		} else {
			alert = InteractiveMessageAlertController(
				titleText: message.title,
				messageText: text,
				imageURL: nil,
				image: image,
				actionHandler: {
					action in
					MobileMessaging.handleAction(
						identifier: action.identifier,
						category: nil,
						message: message,
						notificationUserInfo: message.originalPayload,
						responseInfo: nil,
						completionHandler: {}
					)
			})
		}

		alert.dismissHandler = {
			self.alert?.dismiss(animated: true)
			self.group.leave()
		}
		return alert
	}
}

class AlertQueue {
	static let sharedInstace = AlertQueue()
	
	lazy var oq: Foundation.OperationQueue = {
		let ret = Foundation.OperationQueue()
		ret.maxConcurrentOperationCount = 1
		return ret
	}()
	
	func cancelPendingAlerts() {
		oq.cancelAllOperations()
	}
	
	func cancelAllAlerts() {
		cancelPendingAlerts()
	}
	
	func enqueueAlert(message: MTMessage, text: String) {
		oq.addOperation(AlertOperation(with: message, text: text))
	}
}
