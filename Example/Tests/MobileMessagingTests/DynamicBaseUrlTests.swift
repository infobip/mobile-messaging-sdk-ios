//
//  DynamicBaseUrlTests.swift
//  MobileMessagingExample
//
//  Created by Andrey Kadochnikov on 24/11/2017.
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

	override func getDataResponse(_ r: RequestData, completion: @escaping (JSON?, NSError?) -> Void) {
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
		let responseWithNewBaseUrl = HTTPURLResponse(url: initialUrl, statusCode: 200, httpVersion: nil, headerFields: [Consts.DynamicBaseUrlConsts.newBaseUrlHeader: "https://new.com"])
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
	
    func testThatNewBaseUrlIsAppliedWhenReceivedFromBaseUrlEndpint() {
        // given
        weak var ex = expectation(description: "expectation")
        let sessionManager = MobileMessaging.httpSessionManager!
        let remoteApi = RemoteAPIProviderStub()
        remoteApi.getBaseUrlClosure = { _ -> BaseUrlResult in
            return BaseUrlResult.Success(BaseUrlResponse(baseUrl: "https://new.com"))
        }
        mobileMessagingInstance.remoteApiProvider = remoteApi
        
        // when
        mobileMessagingInstance.baseUrlManager.checkBaseUrl {
            ex?.fulfill()
        }
        
        // then
        self.waitForExpectations(timeout: 10) { _ in
            XCTAssertEqual(sessionManager.dynamicBaseUrl, URL(string: "https://new.com"))
        }
    }

    
	func testThatWeDoRetryAfterCannotFindHost() {
		weak var registrationFinishedExpectation = expectation(description: "registration finished")
		weak var retriesStartedExpectation = expectation(description: "expectationRetriesStarted")
		let newDynamicURL = URL(string: "https://not-reachable-url.com")!
		MMTestCase.cleanUpAndStop()
		var retriesStarted = false
		let mm = MobileMessaging.withApplicationCode("", notificationType: MMUserNotificationType(options: []) , backendBaseURL: Consts.APIValues.prodDynamicBaseURLString)!
		mm.start()
		mm.apnsRegistrationManager = ApnsRegistrationManagerStub(mmContext: mm)
		let remoteApi = RemoteAPIProviderStub()
		remoteApi.postInstanceClosure = { _, _ -> FetchInstanceDataResult in
			if retriesStarted == false {
				retriesStarted = true
				// here we make sure the very first attempt to register has been sent to a given dynamic base url
				XCTAssertEqual(MobileMessaging.httpSessionManager.dynamicBaseUrl, newDynamicURL)
				retriesStartedExpectation?.fulfill()
			} else {
				// here we make sure the dynamic base url was reset to original base url when retries started
				XCTAssertEqual(MobileMessaging.httpSessionManager.dynamicBaseUrl, MobileMessaging.httpSessionManager.originalBaseUrl)
			}
			return FetchInstanceDataResult.Failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost, userInfo: nil))
		}
		mm.remoteApiProvider = remoteApi

		MobileMessaging.httpSessionManager.originalBaseUrl = URL(string: "https://initial-stub.com")!
		MobileMessaging.httpSessionManager.dynamicBaseUrl = newDynamicURL
		
		// make sure base urls prepared correctly
		XCTAssertEqual(MobileMessaging.httpSessionManager.dynamicBaseUrl, newDynamicURL)
		XCTAssertEqual(MobileMessaging.httpSessionManager.originalBaseUrl.absoluteString, "https://initial-stub.com")
		XCTAssertNotEqual(MobileMessaging.httpSessionManager.dynamicBaseUrl, MobileMessaging.httpSessionManager.originalBaseUrl)
		
		mm.didRegisterForRemoteNotificationsWithDeviceToken("someToken123123123".data(using: String.Encoding.utf16)!) {  error in
			registrationFinishedExpectation?.fulfill()
		}
		
		self.waitForExpectations(timeout: 10) { _ in }
	}
}
