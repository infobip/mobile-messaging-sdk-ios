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
	
	init(mmContext: MobileMessaging, completionCompanionBlock: ((Any) -> Void)? = nil) {
		self.completionCompanionBlock = completionCompanionBlock
		super.init(mmContext: mmContext, baseURL: "stub", applicationCode: "stub")
	}

	override func perform<R : RequestData>(request: R, exclusively: Bool = false, completion: @escaping (Result<R.ResponseType>) -> Void) {
		completion(Result.Failure(NSError(type: MMInternalErrorType.UnknownError)))
		completionCompanionBlock?(request)
	}
}

final class MMGeoRemoteAPIAlwaysSucceeding : MMRemoteAPIQueue {
	var completionCompanionBlock : ((Any) -> Void)?
	
	init(mmContext: MobileMessaging, completionCompanionBlock: ((Any) -> Void)? = nil) {
		self.completionCompanionBlock = completionCompanionBlock
		super.init(mmContext: mmContext, baseURL: "stub", applicationCode: "stub")
	}
	
	override func perform<R : RequestData>(request: R, exclusively: Bool = false, completion: @escaping (Result<R.ResponseType>) -> Void) {
		let response = R.ResponseType(json: JSON.parse("{ \"messageIds\": {\"tm1\": \"m1\", \"tm2\": \"m2\", \"tm3\": \"m3\"} }"))
		completion(Result.Success(response!))
		completionCompanionBlock?(request)
	}
}

class MMRemoteAPIMock: MMRemoteAPILocalMocks {
	var responseSubstitution: ((_ request: Any) -> JSON?)? // (Request) -> (JSON)
	var performRequestCompanionBlock: ((Any) -> Void)?
	var completionCompanionBlock: ((Any) -> Void)?
	
	convenience init(mmContext: MobileMessaging, performRequestCompanionBlock: ((Any) -> Void)? = nil, completionCompanionBlock: ((Any) -> Void)? = nil, responseSubstitution: ((_ request: Any) -> JSON?)? = nil) {
		
		self.init(baseURLString: MMTestConstants.kTestBaseURLString, appCode: MMTestConstants.kTestCorrectApplicationCode, mmContext: mmContext, performRequestCompanionBlock: performRequestCompanionBlock, completionCompanionBlock: completionCompanionBlock, responseSubstitution: responseSubstitution)
	}
	
	init(baseURLString: String, appCode: String, mmContext: MobileMessaging, performRequestCompanionBlock: ((Any) -> Void)? = nil, completionCompanionBlock: ((Any) -> Void)? = nil, responseSubstitution: ((_ request: Any) -> JSON?)? = nil) {
		self.performRequestCompanionBlock = performRequestCompanionBlock
		self.completionCompanionBlock = completionCompanionBlock
		self.responseSubstitution = responseSubstitution
		super.init(mmContext: mmContext, baseURLString: baseURLString, appCode: appCode)
	}
	
	override func perform<R: RequestData>(request: R, exclusively: Bool = false, completion: @escaping (Result<R.ResponseType>) -> Void) {
        performRequestCompanionBlock?(request)
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
	}
}

extension MobileMessaging {
	func setupMockedQueues(mmContext: MobileMessaging) {
		remoteApiManager.registrationQueue = MMRemoteAPILocalMocks(mmContext: mmContext, baseURLString: remoteAPIBaseURL, appCode: applicationCode)
		remoteApiManager.seenStatusQueue = MMRemoteAPILocalMocks(mmContext: mmContext, baseURLString: remoteAPIBaseURL, appCode: applicationCode)
		remoteApiManager.messageSyncQueue = MMRemoteAPILocalMocks(mmContext: mmContext, baseURLString: remoteAPIBaseURL, appCode: applicationCode)
		remoteApiManager.geofencingServiceQueue = MMRemoteAPILocalMocks(mmContext: mmContext, baseURLString: remoteAPIBaseURL, appCode: applicationCode)
		remoteApiManager.versionFetchingQueue = MMRemoteAPILocalMocks(mmContext: mmContext, baseURLString: remoteAPIBaseURL, appCode: applicationCode)
	}
}

class MMRemoteAPILocalMocks: MMRemoteAPIQueue {
	
	init(mmContext: MobileMessaging, baseURLString: String, appCode: String) {
		super.init(mmContext: mmContext, baseURL: baseURLString, applicationCode: appCode)
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

class MMDateMock: MMDate {
	let nowStub: Date
	init(nowStub: Date) {
		self.nowStub = nowStub
	}
	override var now: Date {
		return nowStub
	}
}

func timeTravel(to date: Date, block: () -> Void) {
	MobileMessaging.date = MMDateMock(nowStub: date)
	block()
	MobileMessaging.date = MMDate()
}

final class MMReachabilityManagerStub: MMNetworkReachabilityManager {
	let isReachable: Bool
	
	init(isReachable: Bool) {
		self.isReachable = isReachable
	}
	
	override func currentlyReachable() -> Bool {
		return isReachable
	}
}

