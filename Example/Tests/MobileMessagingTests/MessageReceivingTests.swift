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
	var showInteractiveAlertAutomaticallyClosure: ((MM_MTMessage) -> Void)?
    override func showModalNotificationAutomatically(forMessage message: MM_MTMessage) {
        showInteractiveAlertAutomaticallyClosure?(message)
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
		let message = MM_MTMessage(messageSyncResponseJson: JSON.parse(jsonStr))
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
		let message = MM_MTMessage(messageSyncResponseJson: JSON.parse(jsonStr))
		XCTAssertEqual(message!.customPayload! as NSDictionary, ["key": "value", "nestedObject": ["key": "value"]] as NSDictionary)
	}
	
	func testJSONToNSObjects() {
		let jsonstring = backendJSONRegularMessage(messageId: "m1")
		let resultDict = [
			"messageId": "m1",
			"aps": ["alert": ["title": "msg_title", "body": "msg_body"], "badge": 6, "sound": "default"],
			Consts.APNSPayloadKeys.internalData: ["sendDateTime": testEnvironmentTimestampMillisSince1970, "internalKey1": "internalValue1", Consts.InternalDataKeys.attachments: [["url": "pic.url", "t": "string"]]],
			Consts.APNSPayloadKeys.customPayload: ["customKey" : "customValue"],
			] as MMAPNSPayload
		let message = MM_MTMessage(messageSyncResponseJson: JSON.parse(jsonstring))
		
		XCTAssertEqual(message!.originalPayload as NSDictionary, resultDict as NSDictionary)
		XCTAssertEqual(message!.customPayload! as NSDictionary, ["customKey" : "customValue"] as NSDictionary)
		XCTAssertFalse(message!.isSilent)
	}
	
	func testSilentJSONToNSObjects() {
		let jsonstring = backendJSONSilentMessage(messageId: "m1")
		let message = MM_MTMessage(messageSyncResponseJson: JSON.parse(jsonstring))
		XCTAssertTrue(message!.isSilent)
	}
	
	func testPayloadParsing() {
		XCTAssertNil(MM_MTMessage(messageSyncResponseJson: JSON.parse(jsonWithoutMessageId)),"Message decoding must throw with nonAPSjson")
		
		let id = UUID().uuidString
		let json = JSON.parse(backendJSONRegularMessage(messageId: id))
		if let message = MM_MTMessage(messageSyncResponseJson: json) {
			XCTAssertFalse(message.isSilent)
			let origPayload = message.originalPayload["aps"] as! MMStringKeyPayload
			XCTAssertEqual((origPayload["alert"] as! MMStringKeyPayload)["body"] as! String, "msg_body", "Message body must be parsed")
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
        MMTestCase.startWithCorrectApplicationCode()
        
		weak var expectation = self.expectation(description: "Check finished")
		let expectedMessagesCount: Int = 5
		var iterationCounter: Int = 0
		sendPushes(apnsNormalMessagePayload, count: expectedMessagesCount) { userInfo in
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: userInfo,  completion: { _ in
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
    
    func testChatMessagesCounter() {
        MMTestCase.startWithCorrectApplicationCode()
        MMInAppChatService.sharedInstance = MMInAppChatService(mmContext: mobileMessagingInstance)
        MMInAppChatService.sharedInstance?.start({ _ in })
        
        let chatPayload = [
            "messageId": "messageId1",
            "aps": ["alert": ["title": "msg_title", "body": "msg_body"], "badge": 6, "sound": "default"],
            Consts.APNSPayloadKeys.internalData: ["messageType": "chat", "sendDateTime": testEnvironmentTimestampMillisSince1970, "internalKey": "internalValue"],
            Consts.APNSPayloadKeys.customPayload: ["customKey": "customValue"]
        ] as [AnyHashable : Any]
        weak var expectation = self.expectation(description: "Check finished")
            
        let payload = MM_MTMessage(payload: chatPayload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false)!.originalPayload
        self.mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: payload,  completion: { _ in
            expectation?.fulfill()
        })
        
        self.waitForExpectations(timeout: 60, handler: { error in
            XCTAssertEqual(MMInAppChatService.sharedInstance?.getMessageCounter, 1)
        })
    }
	
	func testMessagesPersistingForDisabledRegistration() {
        MMTestCase.startWithCorrectApplicationCode()
        
		weak var expectation = self.expectation(description: "Check finished")
		let expectedMessagesCount: Int = 5
		var iterationCounter: Int = 0

		MobileMessaging.sharedInstance?.isPushRegistrationEnabled = false
		MobileMessaging.sharedInstance?.installationService.syncWithServer(userInitiated: false) { _ in
			
			sendPushes(apnsNormalMessagePayload, count: expectedMessagesCount) { userInfo in
				
				self.mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: userInfo,  completion: { _ in
					DispatchQueue.main.async {
						iterationCounter += 1
						if iterationCounter == expectedMessagesCount {
							expectation?.fulfill()
						}
					}
				})
			}
		}
		self.waitForExpectations(timeout: 60, handler: { error in
			XCTAssertEqual(0, MMTestCase.allStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), "There must be not any message in db, since we disabled the registration")
		})
	}

	func testThatSilentMessagesEventsWorks() {
        MMTestCase.startWithCorrectApplicationCode()
        
		let expectedEventsCount: Int = 5
		var eventsCounter: Int = 0
		var messageHandlingCounter: Int = 0
		
		weak var messageHandlingFinished = self.expectation(description: "messages handling finished")
		let notificationName = NSNotification.Name(MMNotificationMessageReceived)
		expectation(forNotification: notificationName, object: nil) { (notification) -> Bool in
			if let message = notification.userInfo?[MMNotificationKeyMessage] as? MM_MTMessage, message.isSilent == true {
				eventsCounter += 1
			}
			return eventsCounter == expectedEventsCount
		}
		
		sendPushes(apnsSilentMessagePayload, count: expectedEventsCount) { userInfo in
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: userInfo, completion: { (error) in
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
        MMTestCase.startWithCorrectApplicationCode()
        
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
        MMTestCase.startWithCorrectApplicationCode()
        
		collectSixTappedMessages(forApplication: ActiveApplicationStub(), additionalPayload: [ApplicationLaunchedByNotification_Key: true]) { (tappedMessages) in
			XCTAssertEqual(tappedMessages.count, 6)
		}
	}
	
	private func collectSixTappedMessages(forApplication application: MMApplication, additionalPayload: [AnyHashable: Any] = [:], assertionsBlock: @escaping ([MM_MTMessage]) -> Void) {
		weak var messageReceived1 = self.expectation(description: "message received")
		weak var messageReceived2 = self.expectation(description: "message received")
		weak var messageReceived3 = self.expectation(description: "message received")
		weak var messageReceived4 = self.expectation(description: "message received")
		weak var localNotificationHandled1 = self.expectation(description: "localNotificationHandled1")
		weak var localNotificationHandled2 = self.expectation(description: "localNotificationHandled2")

		var tappedMessages = [MM_MTMessage]()
		MobileMessaging.application = application
		
		let delegateMock = MessageHandlingDelegateMock()
		delegateMock.didPerformActionHandler = { action, message, _ in
			DispatchQueue.main.async {
				if let message = message, action.identifier == MMNotificationAction.DefaultActionId {
					tappedMessages.append(message)
				}
			}
		}
		MobileMessaging.messageHandlingDelegate = delegateMock
		
		let payload1 = apnsNormalMessagePayload("m1") + additionalPayload
		let payload2 = apnsNormalMessagePayload("m2") + additionalPayload
		
		mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: payload1,  completion: { _ in
			messageReceived1?.fulfill()
			
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: payload1,  completion: { _ in
				messageReceived3?.fulfill()
			})
		})
		
		mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: payload2,  completion: { _ in
			messageReceived2?.fulfill()
			
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: payload2,  completion: { _ in
				messageReceived4?.fulfill()
			})
		})

		let msg1 = MM_MTMessage.init(payload: payload1, deliveryMethod: .push, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false)!
		msg1.appliedAction = MMNotificationAction.defaultAction
		let msg2 = MM_MTMessage.init(payload: payload2, deliveryMethod: .push, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false)!
		msg2.appliedAction = MMNotificationAction.defaultAction
        mobileMessagingInstance.notificationsInteractionService?.handleAnyMessage(msg1, completion: { (result) in
			localNotificationHandled1?.fulfill()
		})
        mobileMessagingInstance.notificationsInteractionService?.handleAnyMessage(msg2, completion: { (result) in
			localNotificationHandled2?.fulfill()
		})
		
		self.waitForExpectations(timeout: 60, handler: { error in
			assertionsBlock(tappedMessages)
		})
	}
	
	func testThatServerSilentMessageParsing() {
		
		let id = UUID().uuidString
		let json = JSON.parse(backendJSONSilentMessage(messageId: id))
		if let message = MM_MTMessage(messageSyncResponseJson: json) {
			XCTAssertTrue(message.isSilent, "Message must be parsed as silent")
			XCTAssertEqual(message.messageId, id, "Message Id must be parsed")
		} else {
			XCTFail("Message decoding failed")
		}
	}

	func testThatNotificationCenterDelegateRecognizesTaps() {
        MMTestCase.startWithCorrectApplicationCode()
        
		weak var eventReceived = self.expectation(description: "eventReceived")
		weak var tapHandled = self.expectation(description: "tapHandled")
		let delegateMock = MessageHandlingDelegateMock()
		delegateMock.didPerformActionHandler = { action, message, _ in
			if action.identifier == MMNotificationAction.DefaultActionId {
				tapHandled?.fulfill()
			}
		}
		MobileMessaging.messageHandlingDelegate = delegateMock

		UserNotificationCenterDelegate.sharedInstance.didReceive(notificationUserInfo: apnsNormalMessagePayload("1"), actionId: MMNotificationAction.DefaultActionId, categoryId: nil, userText: nil, withCompletionHandler: {eventReceived?.fulfill()})

		self.waitForExpectations(timeout: 60, handler: { error in })
	}

	func testThatBannerAlertWillBeResolved() {
        MMTestCase.startWithCorrectApplicationCode()
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


		let m = MM_MTMessage(payload: JSON.parse(jsonStr).dictionaryObject!, deliveryMethod: .push, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false)!
		let options = InteractiveMessageAlertManager.presentationOptions(for: m)
		XCTAssertEqual(m.inAppStyle , MMInAppNotificationStyle.Banner)
		XCTAssertEqual(options, UNNotificationPresentationOptions.make(with: mobileMessagingInstance.userNotificationType))
        self.waitForExpectations(timeout: 60, handler: { error in })
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


		let m = MM_MTMessage(payload: JSON.parse(jsonStr).dictionaryObject!, deliveryMethod: .push, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false)!
		XCTAssertEqual(m.inAppStyle , MMInAppNotificationStyle.Modal)
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


		let m = MM_MTMessage(payload: JSON.parse(jsonStr).dictionaryObject!, deliveryMethod: .push, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false)!
		XCTAssertEqual(m.inAppStyle , MMInAppNotificationStyle.Banner)
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


		let m = MM_MTMessage(payload: JSON.parse(jsonStr).dictionaryObject!, deliveryMethod: .push, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false)!
		XCTAssertEqual(m.inAppStyle , MMInAppNotificationStyle.Modal)
	}

	func testThatModalAlertWillBeShownForModalInAppStyle() {
        MMTestCase.startWithCorrectApplicationCode()
        
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
        MMTestCase.startWithCorrectApplicationCode()
        
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
        MMTestCase.startWithCorrectApplicationCode()
        
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

		class MessageHandlingDelegateStub: MMMessageHandlingDelegate {
			var expectation: XCTestExpectation? = nil
			func inAppWebViewWillShowUp(_ webViewController: MMWebViewController, for message: MM_MTMessage) {
				XCTAssertEqual("http://www.hello.com", webViewController.rootWebViewController!.url)
				expectation?.fulfill()
			}
			func inAppPresentingViewController(for message: MM_MTMessage) -> UIViewController? {
				XCTAssertEqual("http://www.hello.com", message.webViewUrl?.absoluteString)
				return UIApplication.shared.keyWindow?.rootViewController
			}
		}

		let messageHandlingDelegate = MessageHandlingDelegateStub()
		messageHandlingDelegate.expectation = webViewShown
		MobileMessaging.messageHandlingDelegate = messageHandlingDelegate

		UserNotificationCenterDelegate.sharedInstance.didReceive(notificationUserInfo: JSON.parse(message).dictionaryObject!, actionId: MMNotificationAction.DefaultActionId, categoryId: nil, userText: nil, withCompletionHandler: {
			tapEventReceived?.fulfill()

		})

		self.waitForExpectations(timeout: 60, handler: { error in })
	}

	func testThatInAppWebViewNotShownForWebViewUrlWhenDismissAction() {
        MMTestCase.startWithCorrectApplicationCode()
        
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

		class MessageHandlingDelegateStub: MMMessageHandlingDelegate {
			func inAppWebViewWillShowUp(_ webViewController: MMWebViewController, for message: MM_MTMessage) {
				XCTFail()
			}
            func inAppPresentingViewController(for message: MM_MTMessage) -> UIViewController? {
				XCTFail()
				return UIApplication.shared.keyWindow?.rootViewController
			}
		}

		let messageHandlingDelegate = MessageHandlingDelegateStub()
		MobileMessaging.messageHandlingDelegate = messageHandlingDelegate

		UserNotificationCenterDelegate.sharedInstance.didReceive(notificationUserInfo: JSON.parse(message).dictionaryObject!, actionId: MMNotificationAction.DismissActionId, categoryId: nil, userText: nil, withCompletionHandler: {
			tapEventReceived?.fulfill()

		})

		self.waitForExpectations(timeout: 60, handler: { error in })
	}

	func testThatInAppWebViewNotInitializedWhenWebViewUrlOmitted() {
        MMTestCase.startWithCorrectApplicationCode()
        
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

		class MessageHandlingDelegateStub: MMMessageHandlingDelegate {
			func inAppWebViewWillShowUp(_ webViewController: MMWebViewController, for message: MM_MTMessage) {
				XCTFail()
			}
            func inAppPresentingViewController(for message: MM_MTMessage) -> UIViewController? {
				XCTFail()
				return UIApplication.shared.keyWindow?.rootViewController
			}
		}

		let messageHandlingDelegate = MessageHandlingDelegateStub()
		MobileMessaging.messageHandlingDelegate = messageHandlingDelegate

		UserNotificationCenterDelegate.sharedInstance.didReceive(notificationUserInfo: JSON.parse(message).dictionaryObject!, actionId: MMNotificationAction.DefaultActionId, categoryId: nil, userText: nil, withCompletionHandler: {
			tapEventReceived?.fulfill()

		})

		self.waitForExpectations(timeout: 60, handler: { error in })
	}

	private func testThatModalAlertWillBeShownForModalStyle(_ pushJson: String) {
		weak var alertShown = self.expectation(description: "alertShown")
		weak var messageHandled = self.expectation(description: "messageHandled")
		let interactiveMessageAlertManagerMock = InteractiveMessageAlertManagerMock()
		interactiveMessageAlertManagerMock.showInteractiveAlertAutomaticallyClosure = { _ in
			alertShown?.fulfill()
		}
		mobileMessagingInstance.interactiveAlertManager = interactiveMessageAlertManagerMock

		mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: JSON.parse(pushJson).dictionaryObject!, completion: { _ in
			messageHandled?.fulfill()
		})

		self.waitForExpectations(timeout: 60, handler: { error in })
	}
}
