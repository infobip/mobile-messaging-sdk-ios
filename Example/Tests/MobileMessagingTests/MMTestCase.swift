//
//  MMTestCase.swift
//  MobileMessaging
//
//  Created by Andrey K. on 16/04/16.
//

import XCTest
import Foundation
import CoreData
@testable import MobileMessaging

class MMTestCase: XCTestCase {
	var mobileMessagingInstance: MobileMessagingInstance {
		return MobileMessagingInstance.sharedInstance
	}
	
	var storage: MMCoreDataStorage {
		return mobileMessagingInstance.storage!
	}
	
	override func setUp() {
		super.setUp()
		startWithCorrectApplicationCode()
	}
	
	func cleanUpAndStop() {
		mobileMessagingInstance.cleanUpAndStop()
	}
	
	override func tearDown() {
		super.tearDown()
		cleanUpAndStop()
	}
	
	func nonReportedStoredMessagesCount(ctx: NSManagedObjectContext) -> Int {
		var count: Int = 0
		ctx.reset()
		ctx.performBlockAndWait {
			count = MessageManagedObject.MM_countOfEntitiesWithPredicate(NSPredicate(format: "reportSent == false"), inContext: ctx)
		}
		return count
	}
	
	func allStoredMessagesCount(ctx: NSManagedObjectContext) -> Int {
		var count: Int = 0
		ctx.reset()
		MMQueue.Main.queue.executeSync {
			count = MessageManagedObject.MM_countOfEntitiesWithContext(ctx)
		}
		return count
	}
	
	func startWithApplicationCode(code: String) {
		MobileMessagingInstance.start(UIUserNotificationType.Alert, applicationCode: code, storageType: .SQLite, remoteAPIBaseURL: MMTestConstants.kTestBaseURLString)
		MobileMessaging.loggingUtil?.setLoggingOptions([MMLoggingOptions.Console], logLevel: MMLogLevel.All)
	}
	
	func startWithCorrectApplicationCode() {
		MobileMessagingInstance.start(UIUserNotificationType.Alert, applicationCode: MMTestConstants.kTestCorrectApplicationCode, storageType: .SQLite, remoteAPIBaseURL: MMTestConstants.kTestBaseURLString)
		MobileMessaging.loggingUtil?.setLoggingOptions([MMLoggingOptions.Console], logLevel: MMLogLevel.All)
	}
	
	func startWithWrongApplicationCode() {
		MobileMessagingInstance.start(UIUserNotificationType.Alert, applicationCode: MMTestConstants.kTestWrongApplicationCode, storageType: .SQLite, remoteAPIBaseURL: MMTestConstants.kTestBaseURLString)
		MobileMessaging.loggingUtil?.setLoggingOptions([MMLoggingOptions.Console], logLevel: MMLogLevel.All)
	}
}