//
//  InteractiveNotificationsTests.swift
//  MobileMessagingExample
//
//  Created by okoroleva on 24.07.17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import XCTest
import MobileMessaging

class InteractiveNotificationsTests: MMTestCase {
	let actionId = "actionId"
	let categoryId = "categoryId"
	
	func testActionHandlerCalled() {
		weak var actionHandlerCalled = expectation(description: "action handler called")
		weak var testCompleted = expectation(description: "testCompleted")
		let action = MMNotificationAction(identifier: actionId, title: "Action", options: nil) { (message, completion) in
			actionHandlerCalled?.fulfill()
			completion()
		}
		
		let category = MMNotificationCategory(identifier: categoryId, actions: [action!])
		var set = Set<MMNotificationCategory>()
		set.insert(category!)
		
		cleanUpAndStop()
		var mm = mockedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)
		mm = mm?.withInteractiveNotificationCategories(set)
		mm?.start()
		
		MobileMessaging.handleActionWithIdentifier(identifier: actionId, forRemoteNotification: ["messageId": "1", "aps": ["alert": ["body": "text"], "category": categoryId]], responseInfo: nil) {
			testCompleted?.fulfill()
		}
		
		waitForExpectations(timeout: 10, handler: nil)
	}
    
}
