//
//  TestUtils.swift
//  MobileMessaging
//
//  Created by Andrey K. on 21/03/16.
//

import Foundation
@testable import MobileMessaging

struct MMTestConstants {
	static let kTestInvalidInternalID = "someNonexistentInternalID"
	static let kTestCorrectInternalID = "someExistingInternalID"
	static let kTestValidMSISDN = "79697162937"
	static let kTestInvalidMSISDN = "9697162937"
	static let kTestValidEmail = "john@mail.com"
	static let kTestInvalidEmail = "john@mail,com"
	static let kTestCorrectApplicationCode = "someCorrectApplicationID"
	static let kTestWrongApplicationCode = "someWrongApplicationID"
	static let kTestCurrentRegistrationId = "fffe73006f006d00650054006f006b0065006e003200"
	static let kTestOldRegistrationId = "fffe73006f006d00650054006f006b0065006e00"
//	static let kTestBaseURLString = "http://127.0.0.1:18080"
	static let kTestBaseURLString = "http://p4-io-iam-dev-1.infobip.local:8080"
}

enum TestResult {
	case Success()
	case Failure(error: NSError?)
	case Cancel
}

final class TestMMRemoteAPI : MMRemoteAPIQueue {
	
	var testCompletion : (TestResult) -> Void
	
	init(baseURLString: String, appCode: String, testCompletion: (TestResult) -> Void) {
		self.testCompletion = testCompletion
		super.init(baseURL: baseURLString, applicationCode: appCode)
	}
	
	override func performRequest<R: MMHTTPRequestData>(request: R, completion: (Result<R.ResponseType>) -> Void) {
		let requestOperation = MMRetryableRequestOperation<R>(request: request, applicationCode: applicationCode, baseURL: baseURL) { requestResult in
			completion(requestResult)
			
			var testResult : TestResult
			switch requestResult {
			case .Success:
				testResult = TestResult.Success()
			case .Failure(let error):
				testResult = TestResult.Failure(error: error)
			case .Cancel:
				testResult = TestResult.Cancel
			}
			
			self.testCompletion(testResult)
		}
		queue.cancelAllOperations()
		queue.addOperation(requestOperation)
	}
}
