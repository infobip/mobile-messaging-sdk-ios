//
//  MMActionableMessage.swift
//
//  Created by okoroleva on 08.07.16.
//
//

import Foundation

protocol MMActionableMessage {
	static func performAction(identifier: String?, userInfo: [NSObject : AnyObject], responseInfo: [NSObject : AnyObject]?, completionHandler: (Void -> Void)?)
}

extension MMMessage : MMActionableMessage {
	
	var buttonActions: [String: AnyObject]? {
		return interactionsData?[MMAPIKeys.kButtonActions] as? [String: AnyObject]
	}
	
	static func performAction(identifier: String?, userInfo: [NSObject : AnyObject], responseInfo: [NSObject : AnyObject]?, completionHandler: (Void -> Void)?) {
		guard let userInfo = userInfo as? [String: AnyObject], let message = try? MMMessage(payload: userInfo) else {
			return
		}
		var actions = [MMBaseAction]()
		guard
			let identifier = identifier,
			let notificationButton = MMNotificationButtons(rawValue: identifier) else
		{
			return
		}
		
		if	let actionId = notificationButton.predefinedAction(),
			let action = actionId.createInstance(parameters: nil, resultInfo: responseInfo)
		{
			actions.append(action)
		} else if let buttonActions = message.buttonActions?[identifier] as? [AnyObject] {
			for buttonAction in buttonActions {
				let (aId, parameters) = getActionData(buttonAction)
				guard
					let _aId = aId,
					let actionId = MMPredefinedActions(rawValue: _aId),
					let action = actionId.createInstance(parameters: parameters, resultInfo: responseInfo) else {
					continue
				}
				actions.append(action)
			}
		}
		
		let actionsGroup = dispatch_group_create()
		let queueObject = MMQueue.Global.queue

		
		actions.forEach({ (action) in
			dispatch_group_enter(actionsGroup)
			action.perform(message, completion: {
				dispatch_group_leave(actionsGroup)
			})
		})
		
		dispatch_group_notify(actionsGroup, queueObject.queue) {
			completionHandler?()
		}
	}
	
	private static func getActionData(buttonAction: AnyObject) -> (String?, AnyObject?) {
		var aId : String?
		var parameters : AnyObject?
		if let actionId = buttonAction as? String {
			aId = actionId
		} else if let buttonAction = buttonAction as? [String: AnyObject],
			let actionId = buttonAction.keys.first {
			aId = actionId
			parameters = buttonAction[actionId]
		}
		return (aId, parameters)
	}
}