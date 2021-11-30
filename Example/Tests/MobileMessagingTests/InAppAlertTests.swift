//
//  InAppAlertTests.swift
//  MobileMessagingExample
//
//  Created by Andrey Kadochnikov on 10.03.2020.
//

import Foundation

import XCTest
import Foundation
@testable import MobileMessaging

class AlertsDelegate: InAppAlertDelegate {
	var displayed: Bool = false
    var expectationDisplayed: XCTestExpectation?
    init(expectationDisplayed: XCTestExpectation? = nil) {
        self.expectationDisplayed = expectationDisplayed
    }
	func willDisplay(_ message: MM_MTMessage) {
		displayed = true
        expectationDisplayed?.fulfill()
	}
}

class InAppMessageHandlingDelegateShouldNotShow : MMMessageHandlingDelegate {
    func shouldShowModalInAppNotification(for message: MM_MTMessage) -> Bool {
        return false
    }
}

class InAppAlertTests: MMTestCase {
	func testThatInAppAlertShownIfNoExpirationSpecified() {
        MMTestCase.startWithCorrectApplicationCode()
        
		assertAlertShownAutomatically(true, inAppExpiryDateTime: 0, currentDateTime: 0, json: """
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

	func testThatInAppAlertShownIfNotExpired() {
        MMTestCase.startWithCorrectApplicationCode()
		assertAlertShownAutomatically(true, inAppExpiryDateTime: 100, currentDateTime: 0)
	}

	func testThatInAppAlertNotShownIfExpired() {
        MMTestCase.startWithCorrectApplicationCode()
		assertAlertShownAutomatically(false, inAppExpiryDateTime: 0, currentDateTime: 100)
	}
    
    func testThatInAppNotShownAutomaticallyIfFalseInDelegate() {
        MMTestCase.startWithCorrectApplicationCode()
        let inAppDelegate = InAppMessageHandlingDelegateShouldNotShow()
        MobileMessaging.messageHandlingDelegate = inAppDelegate
        assertAlertShownAutomatically(false, inAppExpiryDateTime: 100, currentDateTime: 0)
    }
    
    func testThatInAppShownManuallyIfFalseInDelegate() {
        MMTestCase.startWithCorrectApplicationCode()
        weak var displayed = self.expectation(description: "displayed")
        let inAppDelegate = InAppMessageHandlingDelegateShouldNotShow()
        MobileMessaging.messageHandlingDelegate = inAppDelegate
        let jsonStr  = """
                        {
                            "messageId": "messageId",
                            "aps": {
                                "badge": 6,
                                "sound": "default",
                                "alert": {
                                    "body":"text"
                                }
                            }
                        }
                        """
        let alertDelegate =  AlertsDelegate(expectationDisplayed: displayed)
        mobileMessagingInstance.interactiveAlertManager.delegate = alertDelegate
        MobileMessaging.application = DefaultApplicationStub()
        let message = MM_MTMessage(messageSyncResponseJson: JSON.parse(jsonStr))!
        
        // when
        MobileMessaging.showModalInAppNotification(forMessage: message)
        
        // then
        self.waitForExpectations(timeout: 10, handler: { error in
            XCTAssertEqual(true, alertDelegate.displayed)
        })
    }

	private func assertAlertShownAutomatically(_ shown: Bool, inAppExpiryDateTime: TimeInterval, currentDateTime: TimeInterval, json: String? = nil) {
		weak var messageHandled = self.expectation(description: "messageHandled")
		let jsonStr  = json ?? """
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
								"inAppStyle": 0,
								"inAppExpiryDateTime": \(inAppExpiryDateTime)
							}
						}
						"""

		let alertDelegate =  AlertsDelegate()
		mobileMessagingInstance.interactiveAlertManager.delegate = alertDelegate
		MobileMessaging.application = DefaultApplicationStub() // this is to have root vc uninitialized to avoid alert operation block

		timeTravel(to: Date(timeIntervalSince1970: currentDateTime), block: {
            mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: JSON.parse(jsonStr).dictionaryObject!, completion: { _ in
				messageHandled?.fulfill()
			})
		})
		self.waitForExpectations(timeout: 60, handler: { error in
			XCTAssertEqual(shown, alertDelegate.displayed)
		})
	}
}
