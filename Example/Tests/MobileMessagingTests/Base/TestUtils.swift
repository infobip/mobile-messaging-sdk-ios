//
//  TestUtils.swift
//  MobileMessaging
//
//  Created by Andrey K. on 21/03/16.
//

import Foundation
@testable import MobileMessaging

extension MobileMessaging {
	var isRegistrationStatusNeedSync: Bool {
		return Installation.delta["isPushRegistrationEnabled"] != nil
	}

	var isPushRegistrationEnabled: Bool {
		set {
			let di = self.dirtyInstallation()
			di.isPushRegistrationEnabled = newValue
			di.archiveDirty()
		}
		get {
			return self.resolveInstallation().isPushRegistrationEnabled
		}
	}

	var pushRegistrationId: String? {
		set {
			Installation.modifyAll { (installation) in
				installation.pushRegistrationId = newValue
			}
		}
		get {
			return self.resolveInstallation().pushRegistrationId
		}
	}

	var pushServiceToken: String? {
		set {
			let di = self.dirtyInstallation()
			di.pushServiceToken = newValue
			di.archiveDirty()
		}
		get {
			return self.resolveInstallation().pushRegistrationId
		}
	}

	var isPrimaryDevice: Bool {
		set {
			let di = self.dirtyInstallation()
			di.isPrimaryDevice = newValue
			di.archiveDirty()
		}
		get {
			return self.resolveInstallation().isPrimaryDevice
		}
	}

	var systemDataHash: Int64 {
		set {
			let id = self.internalData()
			id.systemDataHash = newValue
			id.archiveCurrent()
		}
		get {
			return self.internalData().systemDataHash
		}
	}
}

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
}

enum TestResult {
	case success()
	case failure(error: NSError?)
	case cancel
}

final class MMRemoteAPIAlwaysFailing : RemoteAPIQueue {
	var completionCompanionBlock : ((Any) -> Void)?
	
	init(completionCompanionBlock: ((Any) -> Void)? = nil) {
		self.completionCompanionBlock = completionCompanionBlock
		super.init()
	}

	override func perform<R : RequestData>(request: R, exclusively: Bool = false, completion: @escaping (Result<R.ResponseType>) -> Void) {
		completion(Result.Failure(NSError(type: MMInternalErrorType.UnknownError)))
		completionCompanionBlock?(request)
	}
}

final class MMGeoRemoteAPIAlwaysSucceeding : RemoteAPIQueue {
	var completionCompanionBlock : ((Any) -> Void)?
	
	init(completionCompanionBlock: ((Any) -> Void)? = nil) {
		self.completionCompanionBlock = completionCompanionBlock
		super.init()
	}
	
	override func perform<R : RequestData>(request: R, exclusively: Bool = false, completion: @escaping (Result<R.ResponseType>) -> Void) {
		let response = R.ResponseType(json: JSON.parse("{ \"messageIds\": {\"tm1\": \"m1\", \"tm2\": \"m2\", \"tm3\": \"m3\"} }"))
		completion(Result.Success(response!))
		completionCompanionBlock?(request)
	}
}

class MMRemoteAPIMock: RemoteAPILocalMocks {
	var responseMock: ((_ request: Any) -> JSON?)? // (Request) -> (JSON)
	var performRequestCompanionBlock: ((Any) -> Void)?
	var completionCompanionBlock: ((Any?) -> Void)?
	
	convenience init(performRequestCompanionBlock: ((Any) -> Void)? = nil, completionCompanionBlock: ((Any) -> Void)? = nil, responseMock: ((_ request: Any) -> JSON?)? = nil) {
		
		self.init(performRequestCompanionBlock: performRequestCompanionBlock, completionCompanionBlock: completionCompanionBlock, responseSubstitution: responseMock)
	}
	
	init(performRequestCompanionBlock: ((Any) -> Void)? = nil, completionCompanionBlock: ((Any) -> Void)? = nil, responseSubstitution: ((_ request: Any) -> JSON?)? = nil) {
		self.performRequestCompanionBlock = performRequestCompanionBlock
		self.completionCompanionBlock = completionCompanionBlock
		self.responseMock = responseSubstitution
		super.init()
	}
	
	override func perform<R: RequestData>(request: R, exclusively: Bool = false, completion: @escaping (Result<R.ResponseType>) -> Void) {
        performRequestCompanionBlock?(request)
		if let responseSubstitution = responseMock {
			if let responseJSON = responseSubstitution(request) {
				if let errorResponse = RequestError(json: responseJSON) {
					completion(Result.Failure(errorResponse.foundationError))
					self.completionCompanionBlock?(errorResponse)
				} else if let response = R.ResponseType(json: responseJSON) {
					completion(Result.Success(response))
					self.completionCompanionBlock?(response)
				} else {
					completion(Result.Failure(MMInternalErrorType.UnknownError.foundationError))
					self.completionCompanionBlock?(nil)
				}
			} else {
				completion(Result.Failure(MMInternalErrorType.UnknownError.foundationError))
				self.completionCompanionBlock?(nil)
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
	func setupMockedQueues() {
		remoteApiProvider.registrationQueue = RemoteAPILocalMocks()
		remoteApiProvider.seenStatusQueue = RemoteAPILocalMocks()
		remoteApiProvider.messageSyncQueue = RemoteAPILocalMocks()
		remoteApiProvider.versionFetchingQueue = RemoteAPILocalMocks()
	}
}

class RemoteApiInstanceAttributesMock : RemoteAPIProvider {

	var postInstanceClosure: ((String, RequestBody, @escaping (FetchInstanceDataResult) -> Void) -> Void)? = nil
	var patchInstanceClosure: ((String, String, String, RequestBody, @escaping (UpdateInstanceDataResult) -> Void) -> Void)? = nil
	var getInstanceClosure: ((String, String, @escaping (FetchInstanceDataResult) -> Void) -> Void)? = nil
	var deleteInstanceClosure: ((String, String, String, @escaping (UpdateInstanceDataResult) -> Void) -> Void)? = nil

	var patchUserClosure: ((String, String, RequestBody, @escaping (UpdateInstanceDataResult) -> Void) -> Void)? = nil
	var getUserClosure: ((String, String, @escaping (FetchUserDataResult) -> Void) -> Void)? = nil

	override func patchInstance(applicationCode: String, authPushRegistrationId: String, refPushRegistrationId: String, body: RequestBody, completion: @escaping (UpdateInstanceDataResult) -> Void) {
		patchInstanceClosure?(applicationCode, authPushRegistrationId, refPushRegistrationId, body, completion) ?? completion(UpdateInstanceDataResult.Cancel)
	}

	override func getInstance(applicationCode: String, pushRegistrationId: String, completion: @escaping (FetchInstanceDataResult) -> Void) {
		getInstanceClosure?(applicationCode, pushRegistrationId, completion) ?? completion(FetchInstanceDataResult.Cancel)
	}

	override func postInstance(applicationCode: String, body: RequestBody, completion: @escaping (FetchInstanceDataResult) -> Void) {
		postInstanceClosure?(applicationCode, body, completion) ?? completion(FetchInstanceDataResult.Cancel)
	}

	override func deleteInstance(applicationCode: String, pushRegistrationId: String, expiredPushRegistrationId: String, completion: @escaping (UpdateInstanceDataResult) -> Void) {
		deleteInstanceClosure?(applicationCode, pushRegistrationId, expiredPushRegistrationId, completion) ?? completion(UpdateInstanceDataResult.Cancel)
	}

	override func patchUser(applicationCode: String, pushRegistrationId: String, body: RequestBody, completion: @escaping (UpdateUserDataResult) -> Void) {
		patchUserClosure?(applicationCode, pushRegistrationId, body, completion) ?? completion(UpdateUserDataResult.Cancel)
	}

	override func getUser(applicationCode: String, pushRegistrationId: String, completion: @escaping (FetchUserDataResult) -> Void) {
		getUserClosure?(applicationCode, pushRegistrationId, completion) ?? completion(FetchUserDataResult.Cancel)
	}
}

class RemoteApiUserAttributesMock : RemoteAPIProvider {

	var patchClosure: ((String, String, RequestBody, @escaping (UpdateUserDataResult) -> Void) -> Void)? = nil
	var getClosure: ((String, String, @escaping (FetchUserDataResult) -> Void) -> Void)? = nil

	override func patchUser(applicationCode: String, pushRegistrationId: String, body: RequestBody, completion: @escaping (UpdateUserDataResult) -> Void) {
		patchClosure?(applicationCode, pushRegistrationId, body, completion)
	}

	override func getUser(applicationCode: String, pushRegistrationId: String, completion: @escaping (FetchUserDataResult) -> Void) {
		getClosure?(applicationCode, pushRegistrationId, completion)
	}
}

class RemoteAPILocalMocks: RemoteAPIQueue {

	override func perform<R : RequestData>(request: R, exclusively: Bool = false, completion: @escaping (Result<R.ResponseType>) -> Void) {
		if let responseJSON = Mocks.mockedResponseForRequest(request: request, appCode: request.applicationCode, pushRegistrationId: request.pushRegistrationId) {
			
			let statusCode = responseJSON[MockKeys.responseStatus].intValue
			switch statusCode {
			case 0..<400:
				if let response = R.ResponseType(json: responseJSON) {
					completion(Result.Success(response))
				} else {
					print("Could not create response object. Figure out the workaround.")
					completion(Result.Failure(nil))
				}
			case 400..<600:
				if let requestError = RequestError(json: responseJSON) {
					completion(Result.Failure(requestError.foundationError))
				} else {
					completion(Result.Failure(nil))
				}
			default:
				print("Unexpected mocked status code: \(responseJSON)")
				completion(Result.Failure(nil))
			}
		} else {
			completion(Result.Failure(nil))
		}
	}
}

class DateStub: MMDate {
	let nowStub: Date
	init(nowStub: Date) {
		self.nowStub = nowStub
	}
	override var now: Date {
		return nowStub
	}
}

func timeTravel(to date: Date, block: () -> Void) {
	MobileMessaging.date = DateStub(nowStub: date)
	block()
	MobileMessaging.date = MMDate()
}

final class ReachabilityManagerStub: NetworkReachabilityManager {
	let isReachable: Bool
	
	init(isReachable: Bool) {
		self.isReachable = isReachable
	}
	
	override func currentlyReachable() -> Bool {
		return isReachable
	}
}

extension RequestData {
	var pushRegistrationIdHeader: String? {
		return headers?[Consts.APIHeaders.pushRegistrationId]
	}
}

var darthVaderDateOfDeath: NSDate {
	let comps = NSDateComponents()
	comps.year = 1983
	comps.month = 5
	comps.day = 25
	comps.hour = 0
	comps.minute = 0
	comps.second = 0
	comps.timeZone = TimeZone(secondsFromGMT: 0) // has expected timezone
	comps.calendar = Calendar(identifier: Calendar.Identifier.gregorian)
	return comps.date! as NSDate
}

var darthVaderDateOfBirth: Date {
	let comps = NSDateComponents()
	comps.year = 1980
	comps.month = 12
	comps.day = 12
	comps.hour = 0
	comps.minute = 0
	comps.second = 0
	comps.timeZone = TimeZone(secondsFromGMT: 0) // has expected timezone
	comps.calendar = Calendar(identifier: Calendar.Identifier.gregorian)
	return comps.date!
}

class MessagHandlerMock: MMMessageHandler {
	var setSeenWasCalled: (() -> Void)?
	var sendMessageWasCalled: (([MOMessage]) -> Void)?

	override var isRunning: Bool {
		get {
			return true
		}
		set {

		}
	}

	convenience init(originalHandler: MMMessageHandler) {
		self.init(storage: originalHandler.storage, mmContext: originalHandler.mmContext)
	}

	override func syncSeenStatusUpdates(_ completion: ((SeenStatusSendingResult) -> Void)? = nil) {
		completion?(SeenStatusSendingResult.Cancel)
	}

	override func setSeen(_ messageIds: [String], immediately: Bool, completion: ((SeenStatusSendingResult) -> Void)?) {
		setSeenWasCalled?()
		completion?(SeenStatusSendingResult.Cancel)
	}

	override func sendMessages(_ messages: [MOMessage], isUserInitiated: Bool, completion: (([MOMessage]?, NSError?) -> Void)?) {
		sendMessageWasCalled?(messages)
		completion?(messages, nil)
	}

	override func syncMessages(handlingIteration: Int, finishBlock: ((MessagesSyncResult) -> Void)? = nil) {
		finishBlock?(MessagesSyncResult.Cancel)
	}
}
