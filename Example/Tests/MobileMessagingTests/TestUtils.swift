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
	static let kTestBaseURLString = "http://stub.stub.com"
}

enum TestResult {
	case success()
	case failure(error: NSError?)
	case cancel
}

final class MMRemoteAPIAlwaysFailing : MMRemoteAPIQueue {
	var completionCompanionBlock : ((Any) -> Void)?
	
	init(completionCompanionBlock: ((Any) -> Void)? = nil) {
		self.completionCompanionBlock = completionCompanionBlock
		super.init(baseURL: "stub", applicationCode: "stub")
	}

	override func perform<R : RequestData>(request: R, exclusively: Bool = false, completion: @escaping (Result<R.ResponseType>) -> Void) {
		completion(Result.Failure(nil))
		completionCompanionBlock?(request)
	}
}

final class MMRemoteAPIAlwaysSucceeding : MMRemoteAPIQueue {
	var completionCompanionBlock : ((Any) -> Void)?
	
	init(completionCompanionBlock: ((Any) -> Void)? = nil) {
		self.completionCompanionBlock = completionCompanionBlock
		super.init(baseURL: "stub", applicationCode: "stub")
	}
	
	override func perform<R : RequestData>(request: R, exclusively: Bool = false, completion: @escaping (Result<R.ResponseType>) -> Void) {
		let response = R.ResponseType(json: JSON(NSNull()))
		completion(Result.Success(response!))
		completionCompanionBlock?(request)
	}
}

class MMRemoteAPIMock: MMRemoteAPILocalMocks {
	
	var responseSubstitution: ((_ request: Any) -> JSON?)? // (Request) -> (JSON)
	var performRequestCompanionBlock: ((Any) -> Void)?
	var completionCompanionBlock: ((Any) -> Void)?
	
	convenience init(performRequestCompanionBlock: ((Any) -> Void)? = nil, completionCompanionBlock: ((Any) -> Void)? = nil, responseSubstitution: ((_ request: Any) -> JSON?)? = nil) {
		
		self.init(baseURLString: MMTestConstants.kTestBaseURLString, appCode: MMTestConstants.kTestCorrectApplicationCode, performRequestCompanionBlock: performRequestCompanionBlock, completionCompanionBlock: completionCompanionBlock, responseSubstitution: responseSubstitution)
	}
	
	init(baseURLString: String, appCode: String, performRequestCompanionBlock: ((Any) -> Void)? = nil, completionCompanionBlock: ((Any) -> Void)? = nil, responseSubstitution: ((_ request: Any) -> JSON?)? = nil) {
		self.performRequestCompanionBlock = performRequestCompanionBlock
		self.completionCompanionBlock = completionCompanionBlock
		self.responseSubstitution = responseSubstitution
		super.init(baseURLString: baseURLString, appCode: appCode)
	}
	
	override func perform<R : RequestData>(request: R, exclusively: Bool = false, completion: @escaping (Result<R.ResponseType>) -> Void) {
		if let responseSubstitution = responseSubstitution {
			if let responseJSON = responseSubstitution(request), let response = R.ResponseType(json: responseJSON) {
				completion(Result.Success(response))
			} else {
				completion(Result.Failure(nil))
			}
			
		} else {
			super.perform(request: request) { (response) in
				completion(response)
				self.completionCompanionBlock?(response)
			}
		}
		performRequestCompanionBlock?(request)
	}
}

extension MobileMessaging {
	func setupMockedQueues() {
		remoteApiManager.registrationQueue = MMRemoteAPILocalMocks(baseURLString: remoteAPIBaseURL, appCode: applicationCode)
		remoteApiManager.seenStatusQueue = MMRemoteAPILocalMocks(baseURLString: remoteAPIBaseURL, appCode: applicationCode)
		remoteApiManager.messageSyncQueue = MMRemoteAPILocalMocks(baseURLString: remoteAPIBaseURL, appCode: applicationCode)
		remoteApiManager.geofencingServiceQueue = MMRemoteAPILocalMocks(baseURLString: remoteAPIBaseURL, appCode: applicationCode)
		remoteApiManager.versionFetchingQueue = MMRemoteAPILocalMocks(baseURLString: remoteAPIBaseURL, appCode: applicationCode)
	}
}

class MMRemoteAPILocalMocks: MMRemoteAPIQueue {
	
	init(baseURLString: String = MMTestConstants.kTestBaseURLString, appCode: String = MMTestConstants.kTestCorrectApplicationCode) {
		super.init(baseURL: baseURLString, applicationCode: appCode)
	}
	
	override func perform<R : RequestData>(request: R, exclusively: Bool = false, completion: @escaping (Result<R.ResponseType>) -> Void) {
		if let responseJSON = Mocks.mockedResponseForRequest(request: request, appCode: applicationCode) {
			if let requestError = RequestError(json: responseJSON) {
				completion(Result.Failure(requestError.foundationError))
			} else if let response = R.ResponseType(json: responseJSON) {
				completion(Result.Success(response))
			} else {
				completion(Result.Failure(nil))
			}
		} else {
			completion(Result.Failure(nil))
		}
	}
}

func timeTravel(to date: Date, block: () -> Void) {
	let customDateBlock: @convention(block) (AnyObject) -> Date = { _ in date }
	let implementation = imp_implementationWithBlock(unsafeBitCast(customDateBlock, to: AnyObject.self))
	let method = class_getInstanceMethod(NSClassFromString("__NSPlaceholderDate"), #selector(NSObject.init))
	let oldImplementation = method_getImplementation(method)
	method_setImplementation(method, implementation)
	block()
	method_setImplementation(method, oldImplementation)
}
