//
//  MMActionsManager.swift
//
//  Created by okoroleva on 05.07.16.
//
//

import Foundation

class MMActionsManager {
	private static let sharedInstance = MMActionsManager()
	private var queue = MMQueue.Concurrent.newQueue(queueName: "com.mobile-messaging.queue.concurrent.notification-actions-manager")
	private var actionHandlers = [String: Any?]()
	
	private func setActionHandler<T:MMActionResult>(actionId: MMPredefinedActions, handler: ((T) -> Void)?) {
		queue.executeAsyncBarier { 
			self.actionHandlers[actionId.rawValue] = handler
		}
	}
	
	private func executeActionHandler<T: MMActionResult>(result: T, actionId: MMPredefinedActions, completion: @escaping (Void) -> Void) {
		queue.executeAsync { 
			if let handler = self.actionHandlers[actionId.rawValue] as? ((T) -> Void)? {
				handler?(result)
			}
			completion()
		}
	}
	
	static func setActionHandler<T:MMAction>(actionType: T.Type, handler: @escaping (T.Result) -> Void) {
		sharedInstance.setActionHandler(actionId: actionType.actionId, handler: handler)
	}
	
	static func executeActionHandler<T: MMActionResult>(result: T, actionId: MMPredefinedActions, completion: @escaping (Void) -> Void) {
		sharedInstance.executeActionHandler(result: result, actionId: actionId, completion: completion)
	}
}
