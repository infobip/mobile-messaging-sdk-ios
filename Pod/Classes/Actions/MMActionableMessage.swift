//
//  MMActionableMessage.swift
//
//  Created by okoroleva on 08.07.16.
//
//

import Foundation

protocol MMActionableMessage {
	static func performAction(identifier: String, userInfo: [NSObject: AnyObject], responseInfo: [NSObject: AnyObject]?, completionHandler: (Void -> Void)?)
}

extension MMMessage: MMActionableMessage {
	var actions: [String: AnyObject]? {
		return interactionsData?[MMAPIKeys.kButtonActions] as? [String: AnyObject]
	}
	
	static func performAction(identifier: String, userInfo: [NSObject: AnyObject], responseInfo: [NSObject: AnyObject]?, completionHandler: (Void -> Void)?) {
		guard let userInfo = userInfo as? [String: AnyObject], let message = MMMessage(payload: userInfo), let notificationActionId = MMPredefinedNotificationActionId(rawValue: identifier) else
		{
			return
		}
		
		var resultActions = [MMBaseAction]()
		
		if	let action = notificationActionId.createInstance(parameters: nil, resultInfo: responseInfo) {
			resultActions.append(action)
		} else if let messageActions = message.actions?[identifier] as? [AnyObject] {
			for messageAction in messageActions {
				let actionData = getActionData(messageAction)
				if let actionIdStr = actionData.0, let actionId = MMPredefinedNotificationActionId(rawValue: actionIdStr), let action = actionId.createInstance(parameters: actionData.1, resultInfo: responseInfo)
				{
					resultActions.append(action)
				}
			}
		}
		
		let actionsGroup = dispatch_group_create()
		let queueObject = MMQueue.Global.queue

		resultActions.forEach { action in
			dispatch_group_enter(actionsGroup)
			action.perform(message) {
				dispatch_group_leave(actionsGroup)
			}
		}
		
		dispatch_group_notify(actionsGroup, queueObject.queue) {
			completionHandler?()
		}
	}
	
	private static func getActionData(buttonAction: AnyObject) -> (String?, AnyObject?) {
		var aId: String?
		var parameters: AnyObject?
		if let actionId = buttonAction as? String {
			aId = actionId
		} else if let buttonAction = buttonAction as? [String: AnyObject], let actionId = buttonAction.keys.first {
			aId = actionId
			parameters = buttonAction[actionId]
		}
		return (aId, parameters)
	}
}