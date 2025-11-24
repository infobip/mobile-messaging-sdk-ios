// 
//  Example/Tests/MobileMessagingTests/DynamicBaseUrlTests.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import XCTest
import Foundation
@testable import MobileMessaging

class SessionManagerSuccessMock: DynamicBaseUrlHTTPSessionManager {
	var responseJson: (Any) -> JSON

	init(responseJson: @escaping (Any) -> JSON) {
		self.responseJson = responseJson
		super.init(baseURL: URL(string: "https://initial-stub.com")!, sessionConfiguration: MobileMessaging.urlSessionConfiguration, appGroupId: "")
	}
    
    override func getDataResponse(_ r: RequestData, queue: DispatchQueue, completion: @escaping (JSON?, NSError?) -> Void) {
		completion(responseJson(request), nil)
	}
}

class DynamicBaseUrlTests: MMTestCase {

    func testThatBaseUrlRequestAlwaysGoesToDefaultUrl() {
        let initialUrl = URL(string: "https://initial.com")!
        let baseUrlReques = BaseUrlRequest(applicationCode: "appcode")
        let sessionManager = DynamicBaseUrlHTTPSessionManager(baseURL: initialUrl, sessionConfiguration: nil, appGroupId: "")
        XCTAssertEqual(sessionManager.originalBaseUrl.absoluteString, "https://initial.com")
        XCTAssertEqual(sessionManager.dynamicBaseUrl?.absoluteString, "https://initial.com")
        XCTAssertEqual(sessionManager.resolveUrl(baseUrlReques), "https://mobile.infobip.com/mobile/1/baseurl")
    }
    
	func testThatNewBaseUrlIsAppliedForFollowingRequests() {
		let initialUrl = URL(string: "https://initial.com")!
		
		let sessionManager = DynamicBaseUrlHTTPSessionManager(baseURL: initialUrl, sessionConfiguration: nil, appGroupId: "")
		XCTAssertEqual(sessionManager.dynamicBaseUrl?.absoluteString, "https://initial.com")
		
		// assert that DBU changed if a new one received
		let responseWithNewBaseUrl = HTTPURLResponse(url: initialUrl, statusCode: 200, httpVersion: nil, headerFields: [Consts.DynamicBaseUrl.newBaseUrlHeader: "https://new.com"])
		sessionManager.handleDynamicBaseUrl(response: responseWithNewBaseUrl, error: nil)
		XCTAssertEqual(sessionManager.dynamicBaseUrl?.absoluteString, "https://new.com")
		
		// assert that DBU remains the same if new is not present
		let responseWithEmptyBaseUrl = HTTPURLResponse(url: initialUrl, statusCode: 200, httpVersion: nil, headerFields: nil)
		sessionManager.handleDynamicBaseUrl(response: responseWithEmptyBaseUrl, error: nil)
		XCTAssertEqual(sessionManager.dynamicBaseUrl?.absoluteString, "https://new.com")
		
		// assert that cached DBU restored after session reinitialization
		let newSessionManager = DynamicBaseUrlHTTPSessionManager(baseURL: initialUrl, sessionConfiguration: nil, appGroupId: "")
		XCTAssertEqual(sessionManager.dynamicBaseUrl?.absoluteString, "https://new.com")
		
		// assert that DBU reset if specific error happened
		newSessionManager.handleDynamicBaseUrl(response: nil, error: NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost, userInfo: nil))
		XCTAssertEqual(newSessionManager.dynamicBaseUrl?.absoluteString, "https://initial.com")
	}
	
    func testThatNewBaseUrlIsAppliedWhenReceivedFromBaseUrlEndpoint() {
        newBaseUrlTestingFlow(overwritingDefaultURL: true)
    }

    func testThatNewBaseUrlIsAppliedWhenReceivedFromFromDefaultBaseURL() {
        newBaseUrlTestingFlow(overwritingDefaultURL: false)
    }

    func newBaseUrlTestingFlow(overwritingDefaultURL: Bool) {
        if overwritingDefaultURL {
            MMTestCase.startWithCorrectApplicationCode()
        } else {
            MMTestCase.startWithCorrectApplicationCodeDefaultBaseURL()
        }
        // given
        let now = MobileMessaging.date.now.timeIntervalSince1970
        weak var ex = expectation(description: "expectation")
        let sessionManager = mobileMessagingInstance.httpSessionManager!
        sessionManager.resetBaseUrl()
        let remoteApi = RemoteAPIProviderStub()
        let newUrl = "https://new1.com"
        remoteApi.getBaseUrlClosure = { _ -> BaseUrlResult in
            return BaseUrlResult.Success(BaseUrlResponse(baseUrl: newUrl))
        }
        mobileMessagingInstance.remoteApiProvider = remoteApi
        mobileMessagingInstance.baseUrlManager.resetLastCheckDate()
    
        // when
        timeTravel(to: Date(timeIntervalSince1970: now + 24*60*60), block: {
            mobileMessagingInstance.baseUrlManager.checkBaseUrl {
                ex?.fulfill()
            }
        })
        
        // then
        self.waitForExpectations(timeout: 10) { _ in
            if overwritingDefaultURL {
                // When there default URL was overwriting on initialisation, it is respected
                XCTAssertEqual(sessionManager.dynamicBaseUrl, URL(string: MMTestCase.baseURL))
            } else {
                // Otherwise, the new URL should be set in dynamicBaseUrl
                XCTAssertEqual(sessionManager.dynamicBaseUrl, URL(string: newUrl))
            }
        }
    }
    
    func testThatNewBaseUrlNotRequestedUntilItsTime() {
        MMTestCase.startWithCorrectApplicationCode()
        
        // given
        let now = MobileMessaging.date.now.timeIntervalSince1970
        weak var ex = expectation(description: "expectation")
        let sessionManager = mobileMessagingInstance.httpSessionManager!
        sessionManager.resetBaseUrl()
        let initialUrl = sessionManager.dynamicBaseUrl
        let newUrl = "https://new1.com"
        let remoteApi = RemoteAPIProviderStub()
        remoteApi.getBaseUrlClosure = { _ -> BaseUrlResult in
            return BaseUrlResult.Success(BaseUrlResponse(baseUrl: newUrl))
        }
        mobileMessagingInstance.remoteApiProvider = remoteApi
        mobileMessagingInstance.baseUrlManager.resetLastCheckDate(MobileMessaging.date.now)
        
        // when
        timeTravel(to: Date(timeIntervalSince1970: now + 23*60*60), block: {
            mobileMessagingInstance.baseUrlManager.checkBaseUrl {
                ex?.fulfill()
            }
        })
        
        // then
        self.waitForExpectations(timeout: 10) { _ in
            XCTAssertEqual(sessionManager.dynamicBaseUrl, initialUrl)
        }
    }
    
    func testEmptyBaseUrlResponseHandledProperly() {
        MMTestCase.startWithCorrectApplicationCode()
        
        // given
        let now = MobileMessaging.date.now.timeIntervalSince1970
        weak var ex = expectation(description: "expectation")
        let sessionManager = mobileMessagingInstance.httpSessionManager!
        sessionManager.resetBaseUrl()
        let initialUrl = sessionManager.dynamicBaseUrl
        let remoteApi = RemoteAPIProviderStub()
        remoteApi.getBaseUrlClosure = { _ -> BaseUrlResult in
            let jsonStr = ""
            return BaseUrlResult.Success(BaseUrlResponse(json: JSON.parse(jsonStr))!)
        }
        mobileMessagingInstance.remoteApiProvider = remoteApi
        mobileMessagingInstance.baseUrlManager.resetLastCheckDate()
        // when
        
        timeTravel(to: Date(timeIntervalSince1970: now + 24*60*60), block: {
            mobileMessagingInstance.baseUrlManager.checkBaseUrl {
                ex?.fulfill()
            }
        })
        
        // then
        self.waitForExpectations(timeout: 10) { _ in
            XCTAssertEqual(sessionManager.dynamicBaseUrl, initialUrl)
        }
    }
    
    func testBaseUrlResetDuringMMCleanup() {
        weak var ex = expectation(description: "expectation")
        MMTestCase.startWithCorrectApplicationCode()
        let defaultBaseUrl = mobileMessagingInstance.httpSessionManager.originalBaseUrl
        let otherBaseUrl = URL(string: "http://something.com")!
        
        mobileMessagingInstance.httpSessionManager.setNewBaseUrl(newBaseUrl: otherBaseUrl)
        XCTAssertEqual(self.mobileMessagingInstance.httpSessionManager.dynamicBaseUrl, otherBaseUrl)
        
        mobileMessagingInstance.cleanUpAndStop(false) {
            MMTestCase.startWithCorrectApplicationCode()
            XCTAssertEqual(self.mobileMessagingInstance.httpSessionManager.dynamicBaseUrl, defaultBaseUrl)
            ex?.fulfill()
        }
        
        // then
        self.waitForExpectations(timeout: 10) { _ in }
    }
    
	func testThatWeDoRetryAfterCannotFindHost() {
        //FIXME: this test is invalid. DynamicBaseUrlHTTPSessionManager.handleDynamicBaseUrl is not covered.
//		weak var registrationFinishedExpectation = expectation(description: "registration finished")
//		weak var retriesStartedExpectation = expectation(description: "expectationRetriesStarted")
//		let newDynamicURL = URL(string: "http://not-reachable-url.com")!
//		var retriesStarted = false
//		let mm = MobileMessaging.withApplicationCode("", notificationType: MMUserNotificationType(options: []) , backendBaseURL: Consts.APIValues.prodDynamicBaseURLString)!
//		mm.doStart()
//		mm.apnsRegistrationManager = ApnsRegistrationManagerStub(mmContext: mm)
//		let remoteApi = RemoteAPIProviderStub()
//        
//		remoteApi.postInstanceClosure = { _, _ -> FetchInstanceDataResult in
//			if retriesStarted == false {
//				retriesStarted = true
//				// here we make sure the very first attempt to register has been sent to a given dynamic base url
//				XCTAssertEqual(mm.httpSessionManager.dynamicBaseUrl, newDynamicURL)
//				retriesStartedExpectation?.fulfill()
//			} else {
//				// here we make sure the dynamic base url was reset to original base url when retries started
//				XCTAssertEqual(mm.httpSessionManager.dynamicBaseUrl, mm.httpSessionManager.originalBaseUrl)
//			}
//			return FetchInstanceDataResult.Failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost, userInfo: nil))
//		}
//		mm.remoteApiProvider = remoteApi
//        remoteApi.sessionManager = mm.httpSessionManager
//		mm.httpSessionManager.originalBaseUrl = URL(string: "https://initial-stub.com")!
//		mm.httpSessionManager.dynamicBaseUrl = newDynamicURL
//		
//		// make sure base urls prepared correctly
//		XCTAssertEqual(mm.httpSessionManager.dynamicBaseUrl, newDynamicURL)
//		XCTAssertEqual(mm.httpSessionManager.originalBaseUrl.absoluteString, "https://initial-stub.com")
//		XCTAssertNotEqual(mm.httpSessionManager.dynamicBaseUrl, mm.httpSessionManager.originalBaseUrl)
//		
//        mm.didRegisterForRemoteNotificationsWithDeviceToken(userInitiated: false, token: "someToken123123123".data(using: String.Encoding.utf16)!) {  error in
//			registrationFinishedExpectation?.fulfill()
//		}
//		
//		self.waitForExpectations(timeout: 10) { _ in }
	}

	// MARK: - Case-Insensitive Header Tests

	func testThatNewBaseUrlHeaderIsCaseInsensitiveMixedCase() {
		// Test with mixed case "New-Base-URL" (HTTP/1.1 style)
		// Clear any stored base URL from previous tests
		UserDefaults.standard.removeObject(forKey: Consts.DynamicBaseUrl.storedDynamicBaseUrlKey)
		UserDefaults.standard.synchronize()

		let initialUrl = URL(string: "https://initial.com")!
		let sessionManager = DynamicBaseUrlHTTPSessionManager(baseURL: initialUrl, sessionConfiguration: nil, appGroupId: nil)
		XCTAssertEqual(sessionManager.dynamicBaseUrl?.absoluteString, "https://initial.com")

		// Simulate response with mixed case header (HTTP/1.1)
		let responseWithMixedCaseHeader = HTTPURLResponse(url: initialUrl, statusCode: 200, httpVersion: nil, headerFields: ["New-Base-URL": "https://new-mixed.com"])
		sessionManager.handleDynamicBaseUrl(response: responseWithMixedCaseHeader, error: nil)
		XCTAssertEqual(sessionManager.dynamicBaseUrl?.absoluteString, "https://new-mixed.com")
	}

	func testThatNewBaseUrlHeaderIsCaseInsensitiveLowercase() {
		// Test with lowercase "new-base-url" (HTTP/2 style)
		// Clear any stored base URL from previous tests
		UserDefaults.standard.removeObject(forKey: Consts.DynamicBaseUrl.storedDynamicBaseUrlKey)
		UserDefaults.standard.synchronize()

		let initialUrl = URL(string: "https://initial2.com")!
		let sessionManager = DynamicBaseUrlHTTPSessionManager(baseURL: initialUrl, sessionConfiguration: nil, appGroupId: nil)
		XCTAssertEqual(sessionManager.dynamicBaseUrl?.absoluteString, "https://initial2.com")

		// Simulate response with lowercase header (HTTP/2)
		let responseWithLowercaseHeader = HTTPURLResponse(url: initialUrl, statusCode: 200, httpVersion: nil, headerFields: ["new-base-url": "https://new-lower.com"])
		sessionManager.handleDynamicBaseUrl(response: responseWithLowercaseHeader, error: nil)
		XCTAssertEqual(sessionManager.dynamicBaseUrl?.absoluteString, "https://new-lower.com")
	}

	func testThatNewBaseUrlHeaderIsCaseInsensitiveUppercase() {
		// Test with uppercase "NEW-BASE-URL"
		// Clear any stored base URL from previous tests
		UserDefaults.standard.removeObject(forKey: Consts.DynamicBaseUrl.storedDynamicBaseUrlKey)
		UserDefaults.standard.synchronize()

		let initialUrl = URL(string: "https://initial3.com")!
		let sessionManager = DynamicBaseUrlHTTPSessionManager(baseURL: initialUrl, sessionConfiguration: nil, appGroupId: nil)
		XCTAssertEqual(sessionManager.dynamicBaseUrl?.absoluteString, "https://initial3.com")

		// Simulate response with uppercase header
		let responseWithUppercaseHeader = HTTPURLResponse(url: initialUrl, statusCode: 200, httpVersion: nil, headerFields: ["NEW-BASE-URL": "https://new-upper.com"])
		sessionManager.handleDynamicBaseUrl(response: responseWithUppercaseHeader, error: nil)
		XCTAssertEqual(sessionManager.dynamicBaseUrl?.absoluteString, "https://new-upper.com")
	}
}
