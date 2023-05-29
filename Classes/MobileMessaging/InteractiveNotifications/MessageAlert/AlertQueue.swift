//
//  AlertQueue.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 26/04/2018.
//

import Foundation
import UIKit

class AlertOperation: Foundation.Operation, NamedLogger {
	var semaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
	var alert: InteractiveMessageAlertController?
	let message: MM_MTMessage
	let text: String
	
	init(with message: MM_MTMessage, text: String) {
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
			logDebug("downloading image attachment \(String(describing: self.message.contentUrl?.safeUrl))...")
			self.message.downloadImageAttachment(completion: { (url, error) in
				let img: Image?
				if let url = url, let data = try? Data(contentsOf: url) {
					self.logDebug("image attachment downloaded")
					img = DefaultImageProcessor().process(item: ImageProcessItem.data(data), options: [])
				} else {
					self.logDebug("could not dowonload image attachment")
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
			
			if let presentingVc = MobileMessaging.messageHandlingDelegate?.inAppPresentingViewController?(for: self.message) ?? MobileMessaging.application.visibleViewController {
				self.logDebug("presenting in-app alert, root vc: \(presentingVc)")
				presentingVc.present(a, animated: true, completion: nil)
			} else {
				self.logDebug("could not define root vc to present in-app alert")
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
		logDebug("canceled. Message expired?: \(message.isExpired.description)")
		DispatchQueue.main.async() {
			self.alert?.dismiss(animated: false)
		}
		notifyAlertDismissed()
	}
	
	private func makeAlert(with message: MM_MTMessage, image: Image?, text: String) -> InteractiveMessageAlertController {
		let alert : InteractiveMessageAlertController
		
		if let categoryId = message.category, let category = MobileMessaging.category(withId: categoryId), category.actions.first(where: { return $0 is MMTextInputNotificationAction } ) == nil {
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
				dismissTitle: message.inAppDismissTitle,
				openTitle: message.inAppOpenTitle,
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
	
	init() {
		setupObservers()
		// the queue must perform operations only in apps active state
		oq.isSuspended = !MobileMessaging.application.isInForegroundState
	}
	
	private func setupObservers() {
		guard !isTestingProcessRunning else {
			return
		}
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(self.handleAppWillResignActive(notification:)),
			name: UIApplication.willResignActiveNotification, object: nil)

		NotificationCenter.default.addObserver(
			self,
			selector: #selector(self.handleDidBecomeActive(notification:)),
			name: UIApplication.didBecomeActiveNotification, object: nil)
	}
	
	deinit {
		NotificationCenter.default.removeObserver(self)
	}
	
	@objc private func handleDidBecomeActive(notification: Notification) {
		oq.isSuspended = false
	}

	@objc private func handleAppWillResignActive(notification: Notification) {
		oq.isSuspended = true
	}
	
	func cancelAllAlerts() {
		oq.cancelAllOperations()
	}
	
	func enqueueAlert(message: MM_MTMessage, text: String) {
		oq.addOperation(AlertOperation(with: message, text: text))
	}
}
