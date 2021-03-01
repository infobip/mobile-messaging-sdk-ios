//
//  MessageReceivingTests.swift
//  MobileMessaging
//
//  Created by Andrey K. on 29/02/16.
//

import XCTest
@testable import MobileMessaging
import UserNotifications


class InteractiveMessageAlertManagerMock : InteractiveMessageAlertManager {
	var showInteractiveAlertClosure: ((MTMessage, Bool) -> Void)?
	override func showModalNotificationIfNeeded(forMessage message: MTMessage) {
		showInteractiveAlertClosure?(message, true)
	}
}

func backendJSONSilentMessage(messageId: String) -> String {
	return """
	{
	"messageId": "\(messageId)",
	"internalData": {
	"silent": {
	"badge": 6,
	"sound": "default",
	"alert": {
	"title": "msg_title",
	"body": "msg_body"
	}
	},
	"sendDateTime": 1503583689984,
	"internalKey1": "internalValue1"
	},
	"customPayload": {
	"customKey": "customValue"
	}
	}
	"""
}

func backendJSONRegularMessage(messageId: String) -> String {
	return """
	{
	"messageId": "\(messageId)",
	"aps": {
	"badge": 6,
	"sound": "default",
	"alert": {
	"title": "msg_title",
	"body": "msg_body"
	}
	},
	"internalData": {
	"sendDateTime": 1503583689984,
	"internalKey1": "internalValue1",
	"atts": [
	{
	"url": "pic.url",
	"t": "string"
	}
	]
	},
	"customPayload": {
	"customKey": "customValue"
	}
	}
	"""
}

let jsonWithoutMessageId = "{\"foo\":\"bar\"}"

func apnsSilentMessagePayload(_ messageId: String) -> [AnyHashable: Any] {
	return [
		"messageId": messageId,
		"aps": ["content-available": 1, "badge": 6],
		Consts.APNSPayloadKeys.internalData: ["sendDateTime": testEnvironmentTimestampMillisSince1970, "silent" : [ "title": "msg_title", "body": "msg_body", "sound": "default"], "internalKey": "internalValue"],
		Consts.APNSPayloadKeys.customPayload: ["customKey": "customValue"]
	]
}

class MessageReceivingTests: MMTestCase {
	
	func testLocalizedUserNotificationStringOrFallback() {
		XCTAssertEqual(String.localizedUserNotificationStringOrFallback(key: "LOCALIZABLE_MESSAGE_KEY", args: ["args"], fallback: "fallback"), "A localizable message with a placeholder args")
		XCTAssertEqual(String.localizedUserNotificationStringOrFallback(key: "LOCALIZABLE_MESSAGE_KEY", args: nil, 		fallback: "fallback"), "A localizable message with a placeholder %@")
		XCTAssertEqual(String.localizedUserNotificationStringOrFallback(key: "NON_EXISTENT_KEY", 		args: ["args"], fallback: "fallback"), "NON_EXISTENT_KEY")
		XCTAssertEqual(String.localizedUserNotificationStringOrFallback(key: "NON_EXISTENT_KEY", 		args: nil, 		fallback: "fallback"), "NON_EXISTENT_KEY")
		XCTAssertEqual(String.localizedUserNotificationStringOrFallback(key: nil, 						args: ["Foo"], 	fallback: "fallback"), "fallback")
	}
	
	func testMessageLocalization() {
		let jsonStr  = """
						{
							"messageId": "messageId",
							"aps": {
								"badge": 6,
								"sound": "default",
								"alert": {
									"title-loc-key": "LOCALIZABLE_MESSAGE_KEY",
									"title-loc-args": ["title args"],
									"loc-key": "LOCALIZABLE_MESSAGE_KEY",
									"loc-args": ["text args"]
								}
							}
						}
						"""
		let message = MTMessage(messageSyncResponseJson: JSON.parse(jsonStr))
		XCTAssertEqual(message!.text!, "A localizable message with a placeholder text args")
		XCTAssertEqual(message!.title!, "A localizable message with a placeholder title args")
	}

	func testCustomPayloadNestedObjects() {
		let jsonStr  = """
						{
							"messageId": "messageId",
							"aps": {
								"badge": 6,
								"sound": "default",
								"alert": {
									"body":"text"
								}
							},
							"customPayload": {
								"key": "value",
								"nestedObject": {
									"key": "value"
								}
							}
						}
						"""
		let message = MTMessage(messageSyncResponseJson: JSON.parse(jsonStr))
		XCTAssertEqual(message!.customPayload! as NSDictionary, ["key": "value", "nestedObject": ["key": "value"]] as NSDictionary)
	}
	
	func testJSONToNSObjects() {
		let jsonstring = backendJSONRegularMessage(messageId: "m1")
		let resultDict = [
			"messageId": "m1",
			"aps": ["alert": ["title": "msg_title", "body": "msg_body"], "badge": 6, "sound": "default"],
			Consts.APNSPayloadKeys.internalData: ["sendDateTime": testEnvironmentTimestampMillisSince1970, "internalKey1": "internalValue1", Consts.InternalDataKeys.attachments: [["url": "pic.url", "t": "string"]]],
			Consts.APNSPayloadKeys.customPayload: ["customKey" : "customValue"],
			] as APNSPayload
		let message = MTMessage(messageSyncResponseJson: JSON.parse(jsonstring))
		
		XCTAssertEqual(message!.originalPayload as NSDictionary, resultDict as NSDictionary)
		XCTAssertEqual(message!.customPayload! as NSDictionary, ["customKey" : "customValue"] as NSDictionary)
		XCTAssertFalse(message!.isSilent)
	}
	
	func testSilentJSONToNSObjects() {
		let jsonstring = backendJSONSilentMessage(messageId: "m1")
		let message = MTMessage(messageSyncResponseJson: JSON.parse(jsonstring))
		XCTAssertTrue(message!.isSilent)
	}
	
	func testPayloadParsing() {
		XCTAssertNil(MTMessage(messageSyncResponseJson: JSON.parse(jsonWithoutMessageId)),"Message decoding must throw with nonAPSjson")
		
		let id = UUID().uuidString
		let json = JSON.parse(backendJSONRegularMessage(messageId: id))
		if let message = MTMessage(messageSyncResponseJson: json) {
			XCTAssertFalse(message.isSilent)
			let origPayload = message.originalPayload["aps"] as! StringKeyPayload
			XCTAssertEqual((origPayload["alert"] as! StringKeyPayload)["body"] as! String, "msg_body", "Message body must be parsed")
			XCTAssertEqual(origPayload["sound"] as! String, "default", "sound must be parsed")
			XCTAssertEqual(origPayload["badge"] as! Int, 6, "badger must be parsed")

			XCTAssertEqual(message.messageId, id, "Message Id must be parsed")
			XCTAssertEqual(message.contentUrl, "pic.url")
			
			XCTAssertEqual(message.sendDateTime, testEnvironmentTimestampMillisSince1970/1000, accuracy: 0.0001)
		} else {
			XCTFail("Message decoding failed")
		}
	}

	func testMessagesPersisting() {
		weak var expectation = self.expectation(description: "Check finished")
		let expectedMessagesCount: Int = 5
		var iterationCounter: Int = 0
		sendPushes(apnsNormalMessagePayload, count: expectedMessagesCount) { userInfo in
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInfo,  completion: { _ in
				DispatchQueue.main.async {
					iterationCounter += 1
					if iterationCounter == expectedMessagesCount {
						expectation?.fulfill()
					}
				}
			})
		}
		self.waitForExpectations(timeout: 60, handler: { error in
			XCTAssertEqual(MMTestCase.allStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), expectedMessagesCount, "Messages must be persisted properly")
		})
	}
	
	func testMessagesPersistingForDisabledRegistration() {
		weak var expectation = self.expectation(description: "Check finished")
		let expectedMessagesCount: Int = 5
		var iterationCounter: Int = 0

		MobileMessaging.sharedInstance?.isPushRegistrationEnabled = false
		MobileMessaging.sharedInstance?.installationService.syncWithServer({ _ in
			
			sendPushes(apnsNormalMessagePayload, count: expectedMessagesCount) { userInfo in
				
				self.mobileMessagingInstance.didReceiveRemoteNotification(userInfo,  completion: { _ in
					DispatchQueue.main.async {
						iterationCounter += 1
						if iterationCounter == expectedMessagesCount {
							expectation?.fulfill()
						}
					}
				})
			}
		})
		self.waitForExpectations(timeout: 60, handler: { error in
			XCTAssertEqual(0, MMTestCase.allStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), "There must be not any message in db, since we disabled the registration")
		})
	}

	func testThatSilentMessagesEvenWorks() {
		let expectedEventsCount: Int = 5
		var eventsCounter: Int = 0
		var messageHandlingCounter: Int = 0
		
		weak var messageHandlingFinished = self.expectation(description: "messages handling finished")
		
		#if swift(>=4)
		let notificationName = NSNotification.Name(MMNotificationMessageReceived)
		#else
		let notificationName = MMNotificationMessageReceived
		#endif
		expectation(forNotification: notificationName, object: nil) { (notification) -> Bool in
			if let message = notification.userInfo?[MMNotificationKeyMessage] as? MTMessage, message.isSilent == true {
				eventsCounter += 1
			}
			return eventsCounter == expectedEventsCount
		}
		
		sendPushes(apnsSilentMessagePayload, count: expectedEventsCount) { userInfo in
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInfo, completion: { (error) in
				messageHandlingCounter += 1
				if (messageHandlingCounter == 5) {
					messageHandlingFinished?.fulfill()
				}
			})
		}
		
		self.waitForExpectations(timeout: 60, handler: { _ in
			XCTAssertEqual(eventsCounter, expectedEventsCount, "We should receive exact same amount of events")
		})
	}
	
	func testTapHandlingForInactiveApplication() {
		collectSixTappedMessages(forApplication: InactiveApplicationStub()) { tappedMessages in

			XCTAssertEqual(tappedMessages.count, 6)
			
			XCTAssertTrue(tappedMessages.contains(where: { (m) -> Bool in
				return m.messageId == "m1"
			}))
			
			XCTAssertTrue(tappedMessages.contains(where: { (m) -> Bool in
				return m.messageId == "m2"
			}))
			
			XCTAssertTrue(tappedMessages.contains(where: { (m) -> Bool in
				
				if let cp = m.customPayload {
					let ret = (cp as NSDictionary).isEqual(to: ["customKey": "customValue"])
					return ret
				} else {
					return false
				}
				
			}))
		}
	}

	func testTapHandlerCalledIfUserInfoContainsApplicationLaunchedByNotificationKey() {
		collectSixTappedMessages(forApplication: ActiveApplicationStub(), additionalPayload: [ApplicationLaunchedByNotification_Key: true]) { (tappedMessages) in
			XCTAssertEqual(tappedMessages.count, 6)
		}
	}
	
	private func collectSixTappedMessages(forApplication application: MMApplication, additionalPayload: [AnyHashable: Any] = [:], assertionsBlock: @escaping ([MTMessage]) -> Void) {
		weak var messageReceived1 = self.expectation(description: "message received")
		weak var messageReceived2 = self.expectation(description: "message received")
		weak var messageReceived3 = self.expectation(description: "message received")
		weak var messageReceived4 = self.expectation(description: "message received")
		weak var localNotificationHandled1 = self.expectation(description: "localNotificationHandled1")
		weak var localNotificationHandled2 = self.expectation(description: "localNotificationHandled2")

		var tappedMessages = [MTMessage]()
		MobileMessaging.application = application
		
		let delegateMock = MessageHandlingDelegateMock()
		delegateMock.didPerformActionHandler = { action, message, _ in
			DispatchQueue.main.async {
				if let message = message, action.identifier == NotificationAction.DefaultActionId {
					tappedMessages.append(message)
				}
			}
		}
		MobileMessaging.messageHandlingDelegate = delegateMock
		
		let payload1 = apnsNormalMessagePayload("m1") + additionalPayload
		let payload2 = apnsNormalMessagePayload("m2") + additionalPayload
		
		mobileMessagingInstance.didReceiveRemoteNotification(payload1,  completion: { _ in
			messageReceived1?.fulfill()
			
			self.mobileMessagingInstance.didReceiveRemoteNotification(payload1,  completion: { _ in
				messageReceived3?.fulfill()
			})
		})
		
		mobileMessagingInstance.didReceiveRemoteNotification(payload2,  completion: { _ in
			messageReceived2?.fulfill()
			
			self.mobileMessagingInstance.didReceiveRemoteNotification(payload2,  completion: { _ in
				messageReceived4?.fulfill()
			})
		})

		let msg1 = MTMessage.init(payload: payload1, deliveryMethod: .push, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false)!
		msg1.appliedAction = NotificationAction.defaultAction
		let msg2 = MTMessage.init(payload: payload2, deliveryMethod: .push, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false)!
		msg2.appliedAction = NotificationAction.defaultAction
		NotificationsInteractionService.sharedInstance?.handleAnyMessage(msg1, completion: { (result) in
			localNotificationHandled1?.fulfill()
		})
		NotificationsInteractionService.sharedInstance?.handleAnyMessage(msg2, completion: { (result) in
			localNotificationHandled2?.fulfill()
		})
		
		self.waitForExpectations(timeout: 60, handler: { error in
			assertionsBlock(tappedMessages)
		})
	}
	
	func testThatServerSilentMessageParsing() {
		
		let id = UUID().uuidString
		let json = JSON.parse(backendJSONSilentMessage(messageId: id))
		if let message = MTMessage(messageSyncResponseJson: json) {
			XCTAssertTrue(message.isSilent, "Message must be parsed as silent")
			XCTAssertEqual(message.messageId, id, "Message Id must be parsed")
		} else {
			XCTFail("Message decoding failed")
		}
	}

	func testThatNotificationCenterDelegateRecognizesTaps() {
		weak var eventReceived = self.expectation(description: "eventReceived")
		weak var tapHandled = self.expectation(description: "tapHandled")
		let delegateMock = MessageHandlingDelegateMock()
		delegateMock.didPerformActionHandler = { action, message, _ in
			if action.identifier == NotificationAction.DefaultActionId {
				tapHandled?.fulfill()
			}
		}
		MobileMessaging.messageHandlingDelegate = delegateMock

		UserNotificationCenterDelegate.sharedInstance.didReceive(notificationUserInfo: apnsNormalMessagePayload("1"), actionId: NotificationAction.DefaultActionId, categoryId: nil, userText: nil, withCompletionHandler: {eventReceived?.fulfill()})

		self.waitForExpectations(timeout: 60, handler: { error in })
	}

	func testThatBannerAlertWillBeResolved() {
		let jsonStr  = """
						{
							"messageId": "messageId",
							"aps": {
								"badge": 6,
								"sound": "default",
								"alert": {
									"body":"text"
								}
							},
							"internalData": {
								"inApp": true,
								"inAppStyle": 1
							}
						}
						"""


		let m = MTMessage(payload: JSON.parse(jsonStr).dictionaryObject!, deliveryMethod: .push, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false)!
		let options = InteractiveMessageAlertManager.presentationOptions(for: m)
		XCTAssertEqual(m.inAppStyle , InAppNotificationStyle.Banner)
		XCTAssertEqual(options, UNNotificationPresentationOptions.make(with: mobileMessagingInstance.userNotificationType))
	}

	func testThatModalAlertWillBeResolved() {
		let jsonStr  = """
						{
							"messageId": "messageId",
							"aps": {
								"badge": 6,
								"sound": "default",
								"alert": {
									"body":"text"
								}
							},
							"internalData": {
								"inApp": true,
								"inAppStyle": 0
							}
						}
						"""


		let m = MTMessage(payload: JSON.parse(jsonStr).dictionaryObject!, deliveryMethod: .push, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false)!
		XCTAssertEqual(m.inAppStyle , InAppNotificationStyle.Modal)
	}

	func testThatBannerAlertWillBeResolvedIf_inApp_isAbsent() {
		let jsonStr  = """
						{
							"messageId": "messageId",
							"aps": {
								"badge": 6,
								"sound": "default",
								"alert": {
									"body":"text"
								}
							},
							"internalData": {
								"inAppStyle": 1
							}
						}
						"""


		let m = MTMessage(payload: JSON.parse(jsonStr).dictionaryObject!, deliveryMethod: .push, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false)!
		XCTAssertEqual(m.inAppStyle , InAppNotificationStyle.Banner)
	}

	func testThatModalAlertWillBeResolvedIf_inApp_isAbsent() {
		let jsonStr  = """
						{
							"messageId": "messageId",
							"aps": {
								"badge": 6,
								"sound": "default",
								"alert": {
									"body":"text"
								}
							},
							"internalData": {
								"inAppStyle": 0
							}
						}
						"""


		let m = MTMessage(payload: JSON.parse(jsonStr).dictionaryObject!, deliveryMethod: .push, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false)!
		XCTAssertEqual(m.inAppStyle , InAppNotificationStyle.Modal)
	}

	func testThatModalAlertWillBeShownForModalInAppStyle() {
		testThatModalAlertWillBeShownForModalStyle("""
						{
							"messageId": "messageId",
							"aps": {
								"badge": 6,
								"sound": "default",
								"alert": {
									"body":"text"
								}
							},
							"internalData": {
								"inApp": true,
								"inAppStyle": 0
							}
						}
						""")
	}

	func testThatModalAlertWillBeShownForAbsentInAppStyle() {
		testThatModalAlertWillBeShownForModalStyle("""
						{
							"messageId": "messageId",
							"aps": {
								"badge": 6,
								"sound": "default",
								"alert": {
									"body":"text"
								}
							},
							"internalData": {
								"inApp": true
							}
						}
						""")
	}

	func testThatInAppWebViewShownForWebViewUrlWhenTapActionPerformed() {
		let message = """
			{
				"messageId": "messageId",
				"aps": {
					"badge": 6,
					"sound": "default",
					"alert": {
						"body":"text"
					}
				},
				"internalData": {
					"webViewUrl": "http://www.hello.com"
				}
			}
			"""
		weak var webViewShown = self.expectation(description: "webViewShown")
		weak var tapEventReceived = self.expectation(description: "tapEventReceived")

		class MessageHandlingDelegateStub: MessageHandlingDelegate {
			var expectation: XCTestExpectation? = nil
			func inAppWebViewWillShowUp(_ webViewController: WebViewController, for message: MTMessage) {
				XCTAssertEqual("http://www.hello.com", webViewController.rootWebViewController!.url)
				expectation?.fulfill()
			}
			func inAppPresentingViewController(for message: MTMessage) -> UIViewController? {
				XCTAssertEqual("http://www.hello.com", message.webViewUrl?.absoluteString)
				return UIApplication.shared.keyWindow?.rootViewController
			}
		}

		let messageHandlingDelegate = MessageHandlingDelegateStub()
		messageHandlingDelegate.expectation = webViewShown
		MobileMessaging.messageHandlingDelegate = messageHandlingDelegate

		UserNotificationCenterDelegate.sharedInstance.didReceive(notificationUserInfo: JSON.parse(message).dictionaryObject!, actionId: NotificationAction.DefaultActionId, categoryId: nil, userText: nil, withCompletionHandler: {
			tapEventReceived?.fulfill()

		})

		self.waitForExpectations(timeout: 60, handler: { error in })
	}

	func testThatInAppWebViewNotShownForWebViewUrlWhenDismissAction() {
		let message = """
			{
				"messageId": "messageId",
				"aps": {
					"badge": 6,
					"sound": "default",
					"alert": {
						"body":"text"
					}
				},
				"internalData": {
					"webViewUrl": "www.hello.com"
				}
			}
			"""
		weak var tapEventReceived = self.expectation(description: "tapEventReceived")

		class MessageHandlingDelegateStub: MessageHandlingDelegate {
			func inAppWebViewWillShowUp(_ webViewController: WebViewController, for message: MTMessage) {
				XCTFail()
			}
            func inAppPresentingViewController(for message: MTMessage) -> UIViewController? {
				XCTFail()
				return UIApplication.shared.keyWindow?.rootViewController
			}
		}

		let messageHandlingDelegate = MessageHandlingDelegateStub()
		MobileMessaging.messageHandlingDelegate = messageHandlingDelegate

		UserNotificationCenterDelegate.sharedInstance.didReceive(notificationUserInfo: JSON.parse(message).dictionaryObject!, actionId: NotificationAction.DismissActionId, categoryId: nil, userText: nil, withCompletionHandler: {
			tapEventReceived?.fulfill()

		})

		self.waitForExpectations(timeout: 60, handler: { error in })
	}

	func testThatInAppWebViewNotInitializedWhenWebViewUrlOmitted() {
		let message = """
			{
				"messageId": "messageId",
				"aps": {
					"badge": 6,
					"sound": "default",
					"alert": {
						"body":"text"
					}
				},
				"internalData": {}
			}
			"""
		weak var tapEventReceived = self.expectation(description: "tapEventReceived")

		class MessageHandlingDelegateStub: MessageHandlingDelegate {
			func inAppWebViewWillShowUp(_ webViewController: WebViewController, for message: MTMessage) {
				XCTFail()
			}
            func inAppPresentingViewController(for message: MTMessage) -> UIViewController? {
				XCTFail()
				return UIApplication.shared.keyWindow?.rootViewController
			}
		}

		let messageHandlingDelegate = MessageHandlingDelegateStub()
		MobileMessaging.messageHandlingDelegate = messageHandlingDelegate

		UserNotificationCenterDelegate.sharedInstance.didReceive(notificationUserInfo: JSON.parse(message).dictionaryObject!, actionId: NotificationAction.DefaultActionId, categoryId: nil, userText: nil, withCompletionHandler: {
			tapEventReceived?.fulfill()

		})

		self.waitForExpectations(timeout: 60, handler: { error in })
	}

	private func testThatModalAlertWillBeShownForModalStyle(_ pushJson: String) {
		weak var alertShown = self.expectation(description: "alertShown")
		weak var messageHandled = self.expectation(description: "messageHandled")
		let interactiveMessageAlertManagerMock = InteractiveMessageAlertManagerMock()
		interactiveMessageAlertManagerMock.showInteractiveAlertClosure = { _, _ in
			alertShown?.fulfill()
		}
		mobileMessagingInstance.interactiveAlertManager = interactiveMessageAlertManagerMock

		mobileMessagingInstance.didReceiveRemoteNotification(JSON.parse(pushJson).dictionaryObject!, completion: { _ in
			messageHandled?.fulfill()
		})

		self.waitForExpectations(timeout: 60, handler: { error in })
	}
}
