//
//  AlertQueue.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 26/04/2018.
//

import Foundation

class AlertOperation: Foundation.Operation {
	var semaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
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
		guard shouldProceed else {
			cancelAlert()
			return
		}

		if self.message.contentUrl?.safeUrl != nil {
			MMLogDebug("[InAppAlert] downloading image attachment \(String(describing: self.message.contentUrl?.safeUrl))...")
			self.message.downloadImageAttachment(completion: { (url, error) in
				let img: Image?
				if let url = url, let data = try? Data(contentsOf: url) {
					MMLogDebug("[InAppAlert] image attachment downloaded")
					img = DefaultImageProcessor().process(item: ImageProcessItem.data(data), options: [])
				} else {
					MMLogDebug("[InAppAlert] could not dowonload image attachment")
					img = nil
				}
				self.presentAlert(with: img)
			})
		} else {
			self.presentAlert(with: nil)
		}

		waitUntilAlertDismissed()
	}

	private func waitUntilAlertDismissed() {
		semaphore.wait()
	}

	private func notifyAlertDismissed() {
		semaphore.signal()
	}
	
	private func presentAlert(with image: UIImage?) {
		guard shouldProceed else {
			self.cancelAlert()
			return
		}
		DispatchQueue.main.async() {
			let a = self.makeAlert(with: self.message, image: image, text: self.text)
			self.alert = a
			MobileMessaging.sharedInstance?.interactiveAlertManager?.delegate?.willDisplay(self.message)
			if let rootVc = MobileMessaging.application.rootViewController {
				MMLogDebug("[InAppAlert] presenting in-app alert, root vc: \(rootVc)")
				rootVc.present(a, animated: true, completion: nil)
			} else {
				MMLogDebug("[InAppAlert] could not define root vc to present in-app alert")
				self.cancelAlert()
			}
		}
	}

	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		if keyPath == "isCancelled" {
			if (change?[NSKeyValueChangeKey.newKey] as? Bool ?? false) == true {
				cancelAlert()
			}
		} else {
			return
		}
	}

	private var shouldProceed: Bool {
		return !isCancelled && !message.isExpired
	}

	private func cancelAlert() {
		MMLogDebug("[InAppAlert] canceled. Message expired?: \(message.isExpired.description)")
		DispatchQueue.main.async() {
			self.alert?.dismiss(animated: false)
		}
		notifyAlertDismissed()
	}
	
	private func makeAlert(with message: MTMessage, image: Image?, text: String) -> InteractiveMessageAlertController {
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
						userText: nil,
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
						userText: nil,
						completionHandler: {}
					)
			})
		}

		alert.dismissHandler = {
			self.cancelAlert()
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
	
	func cancelAllAlerts() {
		oq.cancelAllOperations()
	}
	
	func enqueueAlert(message: MTMessage, text: String) {
		oq.addOperation(AlertOperation(with: message, text: text))
	}
}
