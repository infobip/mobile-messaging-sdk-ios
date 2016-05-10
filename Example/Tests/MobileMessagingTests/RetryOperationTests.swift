//
//  RetryOperationTests.swift
//  MobileMessaging
//
//


import XCTest
@testable import MobileMessaging

var operationExecutionCounter: Int = Int.max
let noReachabilityAttemptNumber = 1
var reachabilityTesting = false

final class MMTestNetworkReachabilityManager: MMNetworkReachabilityManager {
	override func currentlyReachable() -> Bool {
		if reachabilityTesting {
			return operationExecutionCounter > noReachabilityAttemptNumber
		} else {
			return true
		}
	}
}

final class MMTestCounterOperation: MMRetryableOperation {
	override func execute() {
		super.execute()
		operationExecutionCounter += 1
		finishWithError(NSError(domain: NSURLErrorDomain, code: 404, userInfo: nil))
	}
}

final class MMTestRechabilityOperation<RequestType: MMHTTPRequestData>: MMRetryableRequestOperation<RequestType> {
	
	required init(retryLimit: Int, completion: MMRetryableOperationCompletion) {
		super.init(retryLimit: retryLimit, completion: completion)
	}
	
	override func execute() {
		super.execute()
		operationExecutionCounter += 1
	}
}

final class RetryOperationTests: XCTestCase {
	
	func testReachabilityLogic() {
		let expectation = expectationWithDescription("Retryable operation finished")
		let r = MMPostRegistrationRequest(internalId: nil, deviceToken: "stub")
		
		let op = MMTestRechabilityOperation(request: r, applicationCode: "stub", baseURL: "stub") { op in
			XCTAssertEqual(operationExecutionCounter, 2, "Operation must be executed 2 times: 1st - initial, 2nd - after we get reachable status")
			expectation.fulfill()
		}
		op.reachabilityManager = MMTestNetworkReachabilityManager()
		let retryOpQ = MMRetryOperationQueue()
		retryOpQ.addOperation(op)
		
		self.waitForExpectationsWithTimeout(30) { error in
			XCTAssertTrue(true)
		}
	}
	
    func testRetryCounters() {
		let expectation = expectationWithDescription("Retryable operation finished")
		let retryLimit = 2
		let opQ = MMRetryOperationQueue()
		let op = MMTestCounterOperation(retryLimit: retryLimit) { op in
			XCTAssertEqual(operationExecutionCounter, retryLimit + 1, "Operation must be executed \(retryLimit + 1) times as we set retry limit \(retryLimit)")
			expectation.fulfill()
		}

		opQ.addOperation(op)
		
		self.waitForExpectationsWithTimeout(10) { error in
			XCTAssertTrue(true)
		}
    }
	
	override func setUp() {
		super.setUp()
		operationExecutionCounter = 0
		reachabilityTesting = true
	}
	
	override func tearDown() {
		super.tearDown()
		reachabilityTesting = false
	}
}
