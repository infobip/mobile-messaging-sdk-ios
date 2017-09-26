//
//  LocalMessageFetchingTests.swift
//  MobileMessagingExample
//
//  Created by Andrey Kadochnikov on 21/09/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//
import XCTest
import Foundation
import UserNotifications
@testable import MobileMessaging

class UserNotificationCenterStorageStub : UserNotificationCenterStorage {
	func getDeliveredMessages(completionHandler: @escaping ([MTMessage]) -> Swift.Void) {
		completionHandler([MTMessage(payload: apnsNormalMessagePayload("m1"))!])
	}
}

class NotificationExtensionStorageStub: AppGroupMessageStorage {
	convenience init?() {
		self.init(applicationCode: "", appGroupId: "")
	}
	
	required init?(applicationCode: String, appGroupId: String) {}
	
	func save(message: MTMessage) {}
	
	func cleanupMessages() {}
	
	func retrieveMessages() -> [MTMessage] {
		return [MTMessage(payload: apnsNormalMessagePayload("m2"))!]
	}
}

class LocalMessageFetchingTests : MMTestCase {
	
	func testThatMessagesFetchedLocallyAreConsideredAsDelivered() {
		if #available(iOS 10.0, *) {
			weak var expectation = self.expectation(description: "server sync finished")
			var dlrs = [String]()
			mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
			mobileMessagingInstance.userNotificationCenterStorage = UserNotificationCenterStorageStub()
			mobileMessagingInstance.sharedNotificationExtensionStorage = NotificationExtensionStorageStub()
			mobileMessagingInstance.remoteApiManager.messageSyncQueue = MMRemoteAPIMock(mmContext: mobileMessagingInstance, performRequestCompanionBlock: { request in
				switch request {
				case (let r as MessagesSyncRequest):
					if let dls = r.dlrMsgIds {
						dlrs.append(contentsOf: dls)
					}
				default:
					break
				}
				
			}, completionCompanionBlock: nil, responseSubstitution:
				{ _ in return JSON(["payloads": []]) }
			)
			mobileMessagingInstance.messageHandler.syncWithServer { (error) in
				expectation?.fulfill()
			}
			
			waitForExpectations(timeout: 10) { (err) in
				XCTAssert(dlrs.contains("m1"))
				XCTAssert(dlrs.contains("m2"))
			}
		}
	}
}
