//
//  UserSessionService.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 17.01.2020.
//

import Foundation
import CoreData

class UserSessionService : MobileMessagingService {
    private let q: DispatchQueue
	var currentSessionId: String? {
		if let pushRegId = mmContext.currentInstallation().pushRegistrationId, let currentSessionStartDate = fetchCurrentSessionStartDate() {
            return "\(pushRegId)_\(currentSessionStartDate.mm_epochUnixTimestamp())"
		} else {
			return nil
		}
	}

	private enum State {
		case suspended
		case resumed
	}
	private var state: State = .suspended
	private let serviceQueue = MMQueue.Serial.New.UserSessionQueue.queue.queue
    private let userSessionPersistingQueue: MMOperationQueue
    private let userSessionReportingQueue: MMOperationQueue
	private var isReportingNeeded = true
	private var timer: RepeatingTimer?
	private let context: NSManagedObjectContext

	init(mmContext: MobileMessaging) {
        self.q = DispatchQueue(label: "user-sessions-service", qos: DispatchQoS.default, attributes: .concurrent, autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit, target: nil)
        self.userSessionPersistingQueue = MMOperationQueue.newSerialQueue(underlyingQueue: q)
        self.userSessionReportingQueue = MMOperationQueue.newSerialQueue(underlyingQueue: q)
		self.context = mmContext.internalStorage.newPrivateContext()
		super.init(mmContext: mmContext, uniqueIdentifier: "UserSessionService")
	}

	//MARK: -

	override func suspend() {
		serviceQueue.async {
			self.logDebug("stops")
			self.timer = nil
			self.cancelOperations()
			super.suspend()
		}
	}

	override func start(_ completion: @escaping (Bool) -> Void) {
        super.start(completion)
		serviceQueue.async {
			self.logDebug("starts")
			self.setupTimer()
		}
	}

	override func mobileMessagingWillStart(_ completion: @escaping () -> Void) {
		start({_ in completion() })
	}

	override func appWillEnterForeground(_ completion: @escaping () -> Void) {
		serviceQueue.async {
			self.isReportingNeeded = true
            completion()
		}
	}

	override func appDidBecomeActive(_ completion: @escaping () -> Void) {
		serviceQueue.async {
			self.logDebug("timer resumes: app did become active state")
			self.timer?.resume()
            completion()
		}
	}

	override func appWillResignActive(_ completion: @escaping () -> Void) {
		serviceQueue.async {
			self.logDebug("timer suspends: app will resign active state")
			self.timer?.suspend()
            completion()
		}
	}

	//MARK: -

	func fetchCurrentSessionStartDate() -> Date? {
		var result: Date? = nil
		context.performAndWait {
			result = fetchCurrentSession()?.startDate
		}
		return result
	}

	func fetchCurrentSession() -> UserSessionReportObject? {
		var result: UserSessionReportObject? = nil
		context.performAndWait {
			result = UserSessionReportObject.MM_find(
				withPredicate: NSPredicate(format: "endDate > %@", MobileMessaging.date.now.addingTimeInterval(-Consts.UserSessions.sessionTimeoutSec) as NSDate),
				fetchLimit: 1,
				sortedBy: "startDate",
				ascending: true,
				inContext: context)?.first
		}
		return result
	}

	func performSessionTracking(doReporting: Bool, completion: @escaping () -> Void) {
		guard MobileMessaging.application.applicationState == .active else {
			logDebug("app is not in active state, skipping session tracking.")
			completion()
			return
		}
		guard let pushRegId = mmContext.currentInstallation().pushRegistrationId else {
			logDebug("no push registration id. Aborting...")
			completion()
			return
		}
		let now = MobileMessaging.date.now

        userSessionPersistingQueue.addOperation(UserSessionPersistingOperation(userInitiated: false, mmContext: mmContext, pushRegId: pushRegId, sessionTimestamp: now, context: context, finishBlock: { [weak self] _ in
            
            guard let _self = self else {
                completion()
                return
            }

			if doReporting {
                _self.isReportingNeeded = false
                if !_self.userSessionReportingQueue.addOperationExclusively(UserSessionsReportingOperation(userInitiated: false, mmContext: _self.mmContext, context: _self.context, finishBlock: {_ in
					completion()
				})) {
					completion()
				}
			} else {
				completion()
			}
		}))
	}

	private func cancelOperations() {
		userSessionPersistingQueue.cancelAllOperations()
		userSessionReportingQueue.cancelAllOperations()
	}

	private func setupTimer() {
        // we don't run timer during tests
		guard !isTestingProcessRunning else {
			return
		}
		timer = RepeatingTimer(timeInterval: Consts.UserSessions.sessionSaveInterval, queue: serviceQueue)
		timer?.eventHandler = handleTimerEvent
		timer?.resume()
	}

	private func handleTimerEvent() { // performs in timerQueue
		assert(!Thread.isMainThread)
		performSessionTracking(doReporting: isReportingNeeded, completion: {  })
	}

	private func setupObservers() {
		guard !isTestingProcessRunning else {
			return
		}
	}
}
