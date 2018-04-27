//
//  AlertQueue.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 26/04/2018.
//

import Foundation

class AlertOperation: Foundation.Operation {
	let group = DispatchGroup()
	let alert: InteractiveMessageAlertController
	
	init(_ alert: InteractiveMessageAlertController) {
		self.alert = alert
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
			self.alert.dismissHandler = {
				self.alert.dismiss(animated: true)
				self.group.leave()
			}
			UIApplication.shared.keyWindow?.rootViewController?.present(self.alert, animated: true, completion: nil)
		}
		
		group.wait()
	}
	
	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		if keyPath == "isCancelled" {
			if (change?[NSKeyValueChangeKey.newKey] as? Bool ?? false) == true {
				self.alert.dismiss(animated: false)
				self.group.leave()
			}
		} else {
			return
		}
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
	
	func enqueueAlert(alert: InteractiveMessageAlertController) {
		oq.addOperation(AlertOperation(alert))
	}
}
