//
//  InteractiveNotificationsTests.swift
//  MobileMessagingExample
//
//  Created by okoroleva on 24.07.17.
//

import XCTest
@testable import MobileMessaging
import UserNotifications

class InteractiveNotificationsTests: MMTestCase {
	let actionId = "actionId"
	let categoryId = "categoryId"
	
	func testThatNotificationTapTriggersSeen() {
		var isSeenSet = false
		weak var seenCalled = self.expectation(description: "seenCalled")
		weak var messageReceived = self.expectation(description: "messageReceived")
		let msgHandlerMock = MessagHandlerMock(originalHandler: mobileMessagingInstance.messageHandler)
		msgHandlerMock.setSeenWasCalled = {
			isSeenSet = true
			seenCalled?.fulfill()
		}
		mobileMessagingInstance.messageHandler = msgHandlerMock

		MobileMessaging.application = InactiveApplicationStub()
		MobileMessaging.didReceiveRemoteNotification(apnsNormalMessagePayload("m1")) { _ in
			messageReceived?.fulfill()
		}
		
		waitForExpectations(timeout: 10, handler: { err in
			XCTAssertTrue(isSeenSet)
		})
	}

	func testActionHandlerCalledAndMOSent() {
		weak var testCompleted = expectation(description: "testCompleted")
		let action = NotificationAction(identifier: actionId, title: "Action", options: [.moRequired])!
		checkActionHandlerCalledAndMoSent(withAction: action, userText: nil) { _action, completionHandler in
			if _action == action {
				testCompleted?.fulfill()
			}
			completionHandler()
		}
		waitForExpectations(timeout: 10, handler: nil)
	}

	func testTextInputActionHandlerCalledAndMOSent() {
		let typedText = "Hello world!"
		weak var testCompleted = expectation(description: "testCompleted")
		let textInputAction = TextInputNotificationAction(identifier: "textInputActionId", title: "Reply", options: [.moRequired], textInputActionButtonTitle: "Reply", textInputPlaceholder: "print text here")!
		checkActionHandlerCalledAndMoSent(withAction: textInputAction, userText: typedText) { _action, completionHandler in
			if let _textInputAction = _action as? TextInputNotificationAction,
				_textInputAction == textInputAction {
				XCTAssertEqual(typedText, _textInputAction.typedText)
				testCompleted?.fulfill()
			}
			completionHandler()
		}
		waitForExpectations(timeout: 10, handler: nil)
	}

	func checkActionHandlerCalledAndMoSent(withAction action: NotificationAction, userText: String?, completion: @escaping (NotificationAction, () -> Void) -> Void) {
		let category = NotificationCategory(identifier: categoryId, actions: [action], options: nil, intentIdentifiers: nil)!
		var set = Set<NotificationCategory>()
		set.insert(category)

		MMTestCase.cleanUpAndStop()

		let mm = MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)!.withInteractiveNotificationCategories(set)
		mm.start()

		let msgHandlerMock = MessagHandlerMock(originalHandler: mobileMessagingInstance.messageHandler)
		weak var seenCalled = expectation(description: "seenCalled")
		weak var actionHandled = expectation(description: "actionHandled")
		weak var sendMessageCalled = expectation(description: "sendMessageCalled")
		msgHandlerMock.sendMessageWasCalled = { messages in
			XCTAssertEqual(messages.first!.text, "\(self.categoryId) \(action.identifier)")
			sendMessageCalled?.fulfill()
		}
		msgHandlerMock.setSeenWasCalled = {
			seenCalled?.fulfill()

		}
		mm.messageHandler = msgHandlerMock

		let messageHandlingDelegateMock = MessageHandlingDelegateMock()
		messageHandlingDelegateMock.didPerformActionHandler = { action, message, _ in
			actionHandled?.fulfill()
			completion(action, {})
		}
		MobileMessaging.messageHandlingDelegate = messageHandlingDelegateMock

		let info = ["messageId": UUID.init().uuidString, "aps": ["alert": ["body": "text"], "category": category.identifier]] as [String : Any]
		let msg = MTMessage(payload: info, deliveryMethod: .push, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false)

		MobileMessaging.handleAction(identifier: action.identifier, category: category.identifier, message: msg, notificationUserInfo: info, userText: userText, completionHandler: {})
	}
	
	func testActionOptions() {
		
		let checkingBlock: ([NotificationActionOptions]) -> Void = { options in
			let action = NotificationAction(identifier: "actionId1", title: "Action", options: options)
			XCTAssertTrue(action != nil)

			let unUserNotificationAction = action!.unUserNotificationAction

			XCTAssertTrue(unUserNotificationAction.options.contains(.authenticationRequired) == options.contains(.authenticationRequired))
			XCTAssertTrue(unUserNotificationAction.options.contains(.destructive) == options.contains(.destructive))
			XCTAssertTrue(unUserNotificationAction.options.contains(.foreground) == options.contains(.foreground))
		}
		
		checkingBlock([.foreground])
		checkingBlock([.destructive])
		checkingBlock([.authenticationRequired])
		checkingBlock([.foreground,.authenticationRequired])
		checkingBlock([.foreground, .destructive])
		checkingBlock([.authenticationRequired, .destructive])
		checkingBlock([.authenticationRequired, .destructive, .foreground])
	}
	
	func testCategoryOptions() {
		let testIntentIds = ["test_intent_id"]
		let action = NotificationAction(identifier: actionId, title: "Action", options: nil)
		XCTAssertNotNil(action)
		let category = NotificationCategory(identifier: categoryId,
											actions: [action!],
											options: [.allowInCarPlay],
											intentIdentifiers: testIntentIds)

		XCTAssertNotNil(category)

		let unCategory = category!.unUserNotificationCategory
		XCTAssertTrue(unCategory.actions.count == 1)
		XCTAssertTrue(unCategory.options.contains(.allowInCarPlay))
		XCTAssertTrue(unCategory.options.contains(.customDismissAction))
		XCTAssertTrue(unCategory.intentIdentifiers == testIntentIds)
	}

	func testThatPredefinedCategoriesWork() {
		weak var testCompleted = expectation(description: "testCompleted")
		XCTAssertEqual(NotificationsInteractionService.sharedInstance?.allNotificationCategories?.count, PredefinedCategoriesTest().categoriesIds?.count)

		let allActions = NotificationsInteractionService.sharedInstance?.allNotificationCategories?.reduce([String](), { (result, category) -> [String] in
			return result + category.actions.reduce([String](), { (result, action) -> [String] in
				return result + ["\(category.identifier)+\(action.identifier)"]
			})
		})

		var actionsWithExpectations = [String: XCTestExpectation]()

		for action in allActions! {
			weak var actionHandled = expectation(description: action)
			actionsWithExpectations[action] = actionHandled
		}

		let messageHandlingDelegateMock = MessageHandlingDelegateMock()
		messageHandlingDelegateMock.didPerformActionHandler = { action, message, _ in
			actionsWithExpectations["\(message!.category!)+\(action.identifier)"]?.fulfill()
		}
		MobileMessaging.messageHandlingDelegate = messageHandlingDelegateMock

		mobileMessagingInstance.messageHandler = MessagHandlerMock(originalHandler: mobileMessagingInstance.messageHandler)

		NotificationsInteractionService.sharedInstance?.allNotificationCategories?.forEach { category in
			category.actions.forEach { action in

				let info = ["messageId": UUID.init().uuidString, "aps": ["alert": ["body": "text"], "category": category.identifier]] as [String : Any]
				let msg = MTMessage(payload: info, deliveryMethod: .push, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false)
				MobileMessaging.handleAction(identifier: action.identifier, category: category.identifier, message: msg, notificationUserInfo: info, userText: nil, completionHandler: {})
			}
		}

		testCompleted?.fulfill()
		waitForExpectations(timeout: 60, handler: nil)
	}

	func testSystemDefinedDismissAction() {
		weak var handlingCompleted = expectation(description: "handlingCompleted")
		weak var testCompleted = expectation(description: "testCompleted")

		let category = NotificationCategory(identifier: categoryId, actions: [], options: [], intentIdentifiers: nil)!
		var set = Set<NotificationCategory>()
		set.insert(category)

		MMTestCase.cleanUpAndStop()

		let mm = MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)!.withInteractiveNotificationCategories(set)
		mm.start()

		let msgHandlerMock = MessagHandlerMock(originalHandler: mobileMessagingInstance.messageHandler)
		weak var seenCalled = expectation(description: "seenCalled")
		msgHandlerMock.setSeenWasCalled = { seenCalled?.fulfill() }
		mm.messageHandler = msgHandlerMock

		let messageHandlingDelegateMock = MessageHandlingDelegateMock()
		messageHandlingDelegateMock.didPerformActionHandler = { action, message, _ in
			if action.identifier == UNNotificationDismissActionIdentifier {
				testCompleted?.fulfill()
			}
		}
		MobileMessaging.messageHandlingDelegate = messageHandlingDelegateMock


		let info = ["messageId": UUID.init().uuidString, "aps": ["alert": ["body": "text"], "category": category.identifier]] as [String : Any]
		let msg = MTMessage(payload: info, deliveryMethod: .push, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false)
		MobileMessaging.handleAction(identifier: UNNotificationDismissActionIdentifier, category: category.identifier, message: msg, notificationUserInfo: info, userText: nil, completionHandler: {
			handlingCompleted?.fulfill()
		})

		waitForExpectations(timeout: 10, handler: nil)
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
			let categories = NSArray(contentsOfFile: path) as? [[String: Any]] {
			let catIds = categories.map { categDict -> String in
				return categDict["identifier"] as! String
			}
			return Set(catIds)
		}
		return nil
	}
}
