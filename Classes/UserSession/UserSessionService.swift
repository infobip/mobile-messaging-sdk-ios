//
//  UserSessionService.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 17.01.2020.
//

import Foundation
import CoreData

class UserSessionService : MobileMessagingService {
	private enum State {
        case suspended
        case resumed
    }
	private var state: State = .suspended
	private let timerQueue = MMQueue.Serial.New.UserSessionQueue.queue.queue
	private let userSessionPersistingQueue = MMOperationQueue.newSerialQueue
	private let userSessionReportingQueue = MMOperationQueue.newSerialQueue
	private var isReportingNeeded = true
	private var timer: RepeatingTimer?
	private let context: NSManagedObjectContext

	init(mmContext: MobileMessaging) {
		self.context = mmContext.internalStorage.newPrivateContext()
		super.init(mmContext: mmContext, id: "UserSessionService")
	}

	override func stop(_ completion: @escaping (Bool) -> Void) {
		timerQueue.async {
			MMLogDebug("[User Session Service] stops")
			self.removeObservers()
			self.timer = nil
			super.stop(completion)
		}
	}

	override func start(_ completion: @escaping (Bool) -> Void) {
		timerQueue.async {
			MMLogDebug("[User Session Service] starts")
			self.setupObservers()
			self.setupTimer()
			super.start(completion)
		}
	}

	override func mobileMessagingWillStart(_ mmContext: MobileMessaging) {
		start({_ in })
	}

	override func mobileMessagingWillStop(_ mmContext: MobileMessaging) {
		stop({_ in})
	}

	func performSessionTracking(doReporting: Bool, completion: @escaping () -> Void) {
		guard let pushRegId = mmContext.currentInstallation().pushRegistrationId else {
			MMLogDebug("[User Session Service] no push registration id. Aborting...")
			completion()
			return
		}
		let now = MobileMessaging.date.now

		userSessionPersistingQueue.addOperation(UserSessionPersistingOperation(mmContext: mmContext, pushRegId: pushRegId, sessionTimestamp: now, context: context, finishBlock: { _ in

			if doReporting {
				self.isReportingNeeded = false
				if !self.userSessionReportingQueue.addOperationExclusively(UserSessionsReportingOperation(mmContext: self.mmContext, context: self.context, finishBlock: {_ in
					completion()
				})) {
					completion()
				}
			} else {
				completion()
			}
		}))
	}

	private func setupTimer() {
		guard !isTestingProcessRunning else {
			return
		}
		timer = RepeatingTimer(timeInterval: Consts.UserSessions.sessionSaveInterval, queue: timerQueue)
		timer?.eventHandler = handleTimerEvent
		timer?.resume()
	}

	private func setupObservers() {
		guard !isTestingProcessRunning else {
			return
		}
		NotificationCenter.default.addObserver(self, selector: #selector(handleAppWillEnterForegroundNotification),
											   name: UIApplication.willEnterForegroundNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleAppWillResignActive),
											   name: UIApplication.willResignActiveNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleDidBecomeActive),
											   name: UIApplication.didBecomeActiveNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleAppWillTerminate),
											   name: UIApplication.willTerminateNotification, object: nil)
	}

	private func removeObservers() {
		NotificationCenter.default.removeObserver(self)
	}

	@objc private func handleDidBecomeActive() {
		timerQueue.async {
			MMLogDebug("[User Session Service] timer resumes: app did become active")
			self.timer?.resume()
		}
	}

	@objc private func handleAppWillEnterForegroundNotification() {
		timerQueue.async {
			MMLogDebug("[User Session Service] timer resumes: app will enter foreground state")
			self.isReportingNeeded = true
			self.timer?.resume()
		}
	}

	@objc private func handleAppWillResignActive() {
		timerQueue.async {
			MMLogDebug("[User Session Service] timer suspends: app will resign active")
			self.timer?.suspend()
		}
	}

	@objc private func handleAppWillTerminate() {
		timerQueue.async {
			MMLogDebug("[User Session Service] timer cancels: app will terminate")
			self.stop({ _ in })
		}
	}

	private func handleTimerEvent() { // performs in timerQueue
		assert(!Thread.isMainThread)
		performSessionTracking(doReporting: isReportingNeeded, completion: {  })
	}
}
