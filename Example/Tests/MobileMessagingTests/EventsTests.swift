// 
//  Example/Tests/MobileMessagingTests/EventsTests.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import XCTest
@testable import MobileMessaging

class EventsTests: MMTestCase {
	func testSuccessfulSyncEventSubmit() {
		MMTestCase.startWithCorrectApplicationCode()

		weak var expectation = self.expectation(description: "expectation1")
		weak var expectation2 = self.expectation(description: "expectation2")
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID

        let date = NSDate()
        //MMDateTime is not supported in events
		let event = MMCustomEvent(definitionId: "event1", properties: [
			"string": "x" as NSString,
			"bool": true as NSNumber,
			"num": 9.5 as NSNumber,
            "date": date as NSDate,
            "nullKey" : NSNull()
		])

		let apiStub =  RemoteAPIProviderStub()
		apiStub.sendCustomEventClosure = { appcode, pushregid, validate, body in

			XCTAssertTrue(validate)
			XCTAssertEqual(body as NSDictionary,
						   [
							"events": [
								[
									"date": "1970-01-01T00:00:00Z",
									"definitionId": "event1",
									"properties": [
										"string": "x",
										"bool": true,
                                        "num": 9.5,
                                        "date": DateStaticFormatters.ISO8601SecondsFormatter.string(from: date as Date) as NSString,
                                        "nullKey": NSNull()
									]
								]
							]
							] as NSDictionary)
			expectation2?.fulfill()
			return CustomEventResult.Success(EmptyResponse())
		}
		timeTravel(to: Date(timeIntervalSince1970: 0), block: {
			mobileMessagingInstance.remoteApiProvider = apiStub
			mobileMessagingInstance.eventsService.submitEvent(customEvent: event, reportImmediately: true) { _ in
				expectation?.fulfill()
			}
		})
		waitForExpectations(timeout: 5, handler: { _ in
			let ctx = self.storage.mainThreadManagedObjectContext!
			let sessions = CustomEventObject.MM_findAllInContext(ctx)!
			XCTAssertTrue(sessions.isEmpty)
		})
	}

	func testFailedAsyncEventSubmit() {
		MMTestCase.startWithCorrectApplicationCode()
        
		weak var expectation = self.expectation(description: "case is finished")
		weak var expectation2 = self.expectation(description: "case is finished")
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID

		let event = MMCustomEvent(definitionId: "event1", properties: [
			"string": "x" as NSString,
			"bool": true as NSNumber,
            "num": 9.5 as NSNumber,
            "date": Date() as NSDate
		])

		let apiStub =  RemoteAPIProviderStub()
		apiStub.sendCustomEventClosure = { appcode, pushregid, validate, body in
			expectation2?.fulfill()
			return CustomEventResult.Failure(nil)
		}

		mobileMessagingInstance.remoteApiProvider = apiStub
		mobileMessagingInstance.eventsService.submitEvent(customEvent: event, reportImmediately: false) { _ in
			expectation?.fulfill()
		}

		waitForExpectations(timeout: 20, handler: { _ in
			let ctx = self.storage.mainThreadManagedObjectContext!
			let sessions = CustomEventObject.MM_findAllInContext(ctx)!
			XCTAssertEqual(sessions.count, 1)
		})
	}
}
