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
	func willDisplay(_ message: MM_MTMessage) {
		displayed = true
	}
}

class InAppAlertTests: MMTestCase {
	func testThatInAppAlertShownIfNoExpirationSpecified() {
		assertAlertShown(true, inAppExpiryDateTime: 0, currentDateTime: 0, json: """
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
		assertAlertShown(true, inAppExpiryDateTime: 100, currentDateTime: 0)
	}

	func testThatInAppAlertNotShownIfExpired() {
		assertAlertShown(false, inAppExpiryDateTime: 0, currentDateTime: 100)
	}

	private func assertAlertShown(_ shown: Bool, inAppExpiryDateTime: TimeInterval, currentDateTime: TimeInterval, json: String? = nil) {
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
			mobileMessagingInstance.didReceiveRemoteNotification(JSON.parse(jsonStr).dictionaryObject!, completion: { _ in
				messageHandled?.fulfill()
			})
		})
		self.waitForExpectations(timeout: 60, handler: { error in
			XCTAssertEqual(shown, alertDelegate.displayed)
		})
	}
}
