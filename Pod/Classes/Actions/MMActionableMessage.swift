//
//  MMActionableMessage.swift
//
//  Created by okoroleva on 08.07.16.
//
//

import Foundation
//TODO: Swift3 check usage of [AnyHashable : Any] instead of [NSObject : AnyObject]
protocol MMActionableMessage {
	static func performAction(identifier: String?, userInfo: [AnyHashable : Any], responseInfo: [AnyHashable : Any]?, completionHandler: @escaping (Void) -> Void)
}

extension MMMessage : MMActionableMessage {
	
	var buttonActions: [String: AnyObject]? {
		return interactionsData?[MMAPIKeys.kButtonActions] as? [String: AnyObject]
	}
	
	static func performAction(identifier: String?, userInfo: [AnyHashable : Any], responseInfo: [AnyHashable : Any]?, completionHandler: @escaping (Void) -> Void) {
		guard let message = MMMessage(payload: userInfo as [NSObject : AnyObject]) else
		{
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
			let action = actionId.createInstance(parameters: nil, resultInfo: responseInfo as [NSObject : AnyObject]?)
		{
			actions.append(action)
		} else if let buttonActions = message.buttonActions?[identifier] as? [AnyObject] {
			for buttonAction in buttonActions {
				let (aId, parameters) = getActionData(buttonAction: buttonAction)
				guard
					let _aId = aId,
					let actionId = MMPredefinedActions(rawValue: _aId),
					let action = actionId.createInstance(parameters: parameters, resultInfo: responseInfo as [NSObject : AnyObject]?) else {
					continue
				}
				actions.append(action)
			}
		}
		
		let actionsGroup = DispatchGroup()
		let queueObject = MMQueue.Global.queue

		
		actions.forEach({ (action) in
			actionsGroup.enter()
			action.perform(message: message, completion: {
				actionsGroup.leave()
			})
		})
		
		actionsGroup.notify(queue: queueObject.queue) {
			completionHandler()
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
