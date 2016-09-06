//
//  MMActionableMessage.swift
//
//  Created by okoroleva on 08.07.16.
//
//

import Foundation

protocol MMActionableMessage {
	static func performAction(identifier: String, userInfo: [AnyHashable : Any], responseInfo: [AnyHashable : Any]?, completionHandler:( @escaping (Void) -> Void)?)
}

extension MMMessage: MMActionableMessage {
	var actions: [String: Any]? {
		return interactionsData?[MMAPIKeys.kButtonActions] as? [String: Any]
	}
	
	static func performAction(identifier: String, userInfo: [AnyHashable : Any], responseInfo: [AnyHashable : Any]?, completionHandler:  (@escaping (Void) -> Void)?) {
		guard let message = MMMessage(payload: userInfo), let notificationActionId = MMPredefinedNotificationActionId(rawValue: identifier) else
		{
			return
		}
		
		var resultActions = [MMBaseAction]()
		
		if	let action = notificationActionId.createInstance(parameters: nil, resultInfo: responseInfo) {
			resultActions.append(action)
		} else if let messageActions = message.actions?[identifier] as? [Any] {
			for messageAction in messageActions {
				let actionData = getActionData(buttonAction: messageAction)
				if let actionIdStr = actionData.0, let actionId = MMPredefinedNotificationActionId(rawValue: actionIdStr), let action = actionId.createInstance(parameters: actionData.1, resultInfo: responseInfo)
				{
					resultActions.append(action)
				}
			}
		}
		
		let actionsGroup = DispatchGroup()
		let queueObject = MMQueue.Global.queue

		
		resultActions.forEach({ (action) in
			actionsGroup.enter()
			action.perform(message: message, completion: {
				actionsGroup.leave()
			})
		})
		
		actionsGroup.notify(queue: queueObject.queue) {
			completionHandler?()
		}
	}
	
	private static func getActionData(buttonAction: Any) -> (String?, Any?) {
		var aId: String?
		var parameters: Any?
		if let actionId = buttonAction as? String {
			aId = actionId
		} else if let buttonAction = buttonAction as? [String: Any], let actionId = buttonAction.keys.first {
			aId = actionId
			parameters = buttonAction[actionId]
		}
		return (aId, parameters)
	}
}
