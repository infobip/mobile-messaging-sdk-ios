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

final class MMStubNetworkReachabilityManager: MMNetworkReachabilityManager {
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
		finishWithError(NSError(domain: NSURLErrorDomain, code: 404, userInfo: [NSLocalizedDescriptionKey: "fake some retryable error"]))
	}
	
	override func isErrorRetryable(_ error: NSError) -> Bool {
		return true
	}
}

final class MMTestRechabilityOperation<RequestType: RequestData>: MMRetryableRequestOperation<RequestType> {
	required init(retryLimit: Int, completion: @escaping MMRetryableOperationCompletion) {
		super.init(retryLimit: retryLimit, completion: completion)
	}
	
	override func execute() {
		super.execute()
		
		operationExecutionCounter += 1
	}
}

final class RetryOperationTests: XCTestCase {
	
	func testReachabilityLogic() {
		weak var expectation = self.expectation(description: "Retryable operation finished")
		let r = RegistrationRequest(deviceToken: "stub", isEnabled: nil, expiredInternalId: nil)
		
		let op = MMTestRechabilityOperation(request: r, reachabilityManager: MMStubNetworkReachabilityManager(), applicationCode: "stub", baseURL: "stub") { op in
			expectation?.fulfill()
		}
		let retryOpQ = MMRetryOperationQueue()
		retryOpQ.addOperation(op)
		
		self.waitForExpectations(timeout: 60) { _ in
			
			XCTAssertEqual(operationExecutionCounter, 2, "Operation must be executed 2 times: 1st - initial, 2nd - after we get reachable status")
			
		}
	}
	
    func testRetryCounters() {
		weak var expectation = self.expectation(description: "Retryable operation finished")
		let retryLimit = 2
		let opQ = MMRetryOperationQueue()
		let op = MMTestCounterOperation(retryLimit: retryLimit) { op in
			expectation?.fulfill()
		}

		opQ.addOperation(op)
		
		self.waitForExpectations(timeout: 60) { _ in
			
			XCTAssertEqual(operationExecutionCounter, retryLimit + 1, "Operation must be executed \(retryLimit + 1) times as we set retry limit \(retryLimit)")
			
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
