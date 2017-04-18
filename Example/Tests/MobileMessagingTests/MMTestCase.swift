
//  MMTestCase.swift
//  MobileMessaging
//
//  Created by Andrey K. on 16/04/16.
//

import XCTest
import Foundation
import CoreData
@testable import MobileMessaging

class ActiveApplicationMock: MMApplication {
	var applicationState: UIApplicationState {
		return .active
	}
	
	var applicationIconBadgeNumber: Int {
		get { return 0 }
		set {}
	}
	
	var isRegisteredForRemoteNotifications: Bool { return true }
	func unregisterForRemoteNotifications() {}
	func registerForRemoteNotifications() {}
	func presentLocalNotificationNow(_ notification: UILocalNotification) {}
	func registerUserNotificationSettings(_ notificationSettings: UIUserNotificationSettings) {}
	var currentUserNotificationSettings: UIUserNotificationSettings? { return nil }
}


class InactiveApplicationMock: MMApplication {
	var applicationState: UIApplicationState {
		return .inactive
	}
	
	var applicationIconBadgeNumber: Int {
		get { return 0 }
		set {}
	}

	var isRegisteredForRemoteNotifications: Bool { return true }
	func unregisterForRemoteNotifications() {}
	func registerForRemoteNotifications() {}
	func presentLocalNotificationNow(_ notification: UILocalNotification) {}
	func registerUserNotificationSettings(_ notificationSettings: UIUserNotificationSettings) {}
	var currentUserNotificationSettings: UIUserNotificationSettings? { return nil }
}

class MMTestCase: XCTestCase {
    var mobileMessagingInstance: MobileMessaging {
        return MobileMessaging.sharedInstance!
    }
    
    var storage: MMCoreDataStorage {
        return self.mobileMessagingInstance.internalStorage
    }
    
    override func setUp() {
        super.setUp()
        MobileMessaging.logger.logOutput = .Console
        MobileMessaging.logger.logLevel = .All
        MobileMessaging.stop(true)
        startWithCorrectApplicationCode()
		self.mobileMessagingInstance.reachabilityManager = MMReachabilityManagerStub(isReachable: true)
    }
    
    func cleanUpAndStop() {
        MobileMessaging.stop(true)
		MobileMessaging.sharedInstance = nil
    }
    
    override func tearDown() {
        super.tearDown()
		cleanUpAndStop()
		MobileMessaging.privacySettings = PrivacySettings()
		MMGeofencingService.currentDate = nil
	}
    
    func nonReportedStoredMessagesCount(_ ctx: NSManagedObjectContext) -> Int {
        var count: Int = 0
        ctx.reset()
        ctx.performAndWait {
            count = MessageManagedObject.MM_countOfEntitiesWithPredicate(NSPredicate(format: "reportSent == false"), inContext: ctx)
        }
        return count
    }
    
    func allStoredMessagesCount(_ ctx: NSManagedObjectContext) -> Int {
        var count: Int = 0
        ctx.reset()
        ctx.performAndWait {
            count = MessageManagedObject.MM_countOfEntitiesWithContext(ctx)
        }
        return count
    }
	
	func startWithApplicationCode(_ code: String) {
		let mm = mockedMMInstanceWithApplicationCode(code)
		mm?.start()
	}
	
	func mockedMMInstanceWithApplicationCode(_ code: String) -> MobileMessaging? {
		let mm = MobileMessaging.withApplicationCode(code, notificationType: [], backendBaseURL: MMTestConstants.kTestBaseURLString)
		mm?.setupMockedQueues(mmContext: self.mobileMessagingInstance)
		mm?.application = ActiveApplicationMock()
		return mm
	}
	
	func startWithCorrectApplicationCode() {
		let mm = mockedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)
		mm?.start()
	}
	
	func startWithWrongApplicationCode() {
		let mm = mockedMMInstanceWithApplicationCode(MMTestConstants.kTestWrongApplicationCode)
		mm?.start()
	}
}
