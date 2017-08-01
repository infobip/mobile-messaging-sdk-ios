//
//  InteractiveNotificationsTests.swift
//  MobileMessagingExample
//
//  Created by okoroleva on 24.07.17.
//

import XCTest
@testable import MobileMessaging

class InteractiveNotificationsTests: MMTestCase {
	let actionId = "actionId"
	let categoryId = "categoryId"
	
	func testActionHandlerCalled() {
		weak var testCompleted = expectation(description: "testCompleted")
		let action = MMNotificationAction(identifier: actionId, title: "Action", options: nil)
		let category = MMNotificationCategory(identifier: categoryId, actions: [action!])
		var set = Set<MMNotificationCategory>()
		set.insert(category!)
		
		cleanUpAndStop()
		var mm = mockedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)
		mm = mm?.withInteractiveNotificationCategories(set)
		mm?.start()
		
		checkThatCategoryActionCalled(category: category!, action: action!) {
			testCompleted?.fulfill()
		}
		
		waitForExpectations(timeout: 10, handler: nil)
	}
	
	func testActionOptions() {
		
		let checkingBlock: ([MMNotificationActionOptions]) -> Void = { options in
			let action = MMNotificationAction(identifier: "actionId1", title: "Action", options: options)
			XCTAssertTrue(action != nil)
			let userNotificationAction = action!.uiUserNotificationAction
			XCTAssertTrue(userNotificationAction.isAuthenticationRequired == options.contains(.authenticationRequired))
			XCTAssertTrue(userNotificationAction.isDestructive == options.contains(.destructive))
			XCTAssertTrue(userNotificationAction.activationMode == (options.contains(.foreground) ? .foreground : .background))
		}
		
		checkingBlock([.foreground])
		checkingBlock([.destructive])
		checkingBlock([.authenticationRequired])
		checkingBlock([.foreground,.authenticationRequired])
		checkingBlock([.foreground, .destructive])
		checkingBlock([.authenticationRequired, .destructive])
		checkingBlock([.authenticationRequired, .destructive, .foreground])
	}
	
	func testThatPredefinedCategoriesWork() {
		weak var testCompleted = expectation(description: "testCompleted")
		XCTAssertEqual(mobileMessagingInstance.interactiveNotificationCategories?.count, PredefinedCategoriesTest().categoriesIds?.count)
		testCompleted?.fulfill()
		
		let allActions = mobileMessagingInstance.interactiveNotificationCategories?.reduce([String : XCTestExpectation](), { (result, category) -> [String : XCTestExpectation] in
			return result + category.actions.reduce([String : XCTestExpectation](), { (result, action) -> [String : XCTestExpectation] in
				return result + ["\(category.identifier)+\(action.identifier)": expectation(description: "\(category.identifier)+\(action.identifier)")]
			})
		})
		
		MobileMessaging.notificationActionHandler = TestNotificationActionHandler(handlingBlock: { (_action, message, completionHandler) in
			allActions?["\(message.category!)+\(_action.identifier)"]?.fulfill()
		})
		
		self.mobileMessagingInstance.interactiveNotificationCategories?.forEach({ (category) in
			category.actions.forEach({ (action) in
				MobileMessaging.handleActionWithIdentifier(identifier: action.identifier, forRemoteNotification: ["messageId": "1", "aps": ["alert": ["body": "text"], "category": category.identifier]], responseInfo: nil) {
					
				}
			})
		})
		
		waitForExpectations(timeout: 60, handler: nil)
	}
	
	private func checkThatCategoryActionCalled(category: MMNotificationCategory, action: MMNotificationAction, completion: @escaping () -> Void) {
		
		MobileMessaging.notificationActionHandler = TestNotificationActionHandler(handlingBlock: { (_action, message, completionHandler) in
			if _action == action {
				completionHandler()
			}
		})
		
		MobileMessaging.handleActionWithIdentifier(identifier: action.identifier, forRemoteNotification: ["messageId": "1", "aps": ["alert": ["body": "text"], "category": category.identifier]], responseInfo: nil) {
			completion()
		}
	}
}

class PredefinedCategoriesTest {
	var bundle: Bundle? {
		return Bundle(identifier:"org.cocoapods.MobileMessaging")
	}
	var path: String? {
		return bundle?.path(forResource: "PredefinedNotificationCategories", ofType: "plist")
	}
	
	var categoriesIds: Set<String>? {
		if let path = path,
			let categoriesDict = NSDictionary(contentsOfFile: path) as? [String: Any] {
			let catIds = categoriesDict.flatMap({ (key, value) -> String in
				return key
			})
			return Set(catIds)
		}
		return nil
	}
}

class TestNotificationActionHandler: NotificationActionHandling {
	let handlingBlock: (_ action: MMNotificationAction, _ message: MTMessage, _ completion: () -> Void) -> Void
	init(handlingBlock: @escaping (_ action: MMNotificationAction, _ message: MTMessage, _ completion: () -> Void) -> Void) {
		self.handlingBlock = handlingBlock
	}
	
	func handle(action: MMNotificationAction, forMessage message: MTMessage, withCompletionHandler completionHandler: @escaping () -> Void) {
		handlingBlock(action, message, completionHandler)
	}
}
