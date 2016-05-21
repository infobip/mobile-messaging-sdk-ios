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

extension MobileMessaging {
	class func testStartWithApplicationCode(code: String) {
		MobileMessagingInstance.loadComponents(code, storageType: .SQLite, remoteAPIBaseURL: MMTestConstants.kTestBaseURLString)
		MobileMessaging.loggingUtil?.setLoggingOptions([MMLoggingOptions.Console], logLevel: MMLogLevel.All)
	}
	class func testStartWithCorrectApplicationCode() {
		MobileMessagingInstance.loadComponents(MMTestConstants.kTestCorrectApplicationCode, storageType: .SQLite, remoteAPIBaseURL: MMTestConstants.kTestBaseURLString)
		MobileMessaging.loggingUtil?.setLoggingOptions([MMLoggingOptions.Console], logLevel: MMLogLevel.All)
	}
	class func testStartWithWrongApplicationCode() {
		MobileMessagingInstance.loadComponents(MMTestConstants.kTestWrongApplicationCode, storageType: .SQLite, remoteAPIBaseURL: MMTestConstants.kTestBaseURLString)
		MobileMessaging.loggingUtil?.setLoggingOptions([MMLoggingOptions.Console], logLevel: MMLogLevel.All)
	}
}

class MMTestCase: XCTestCase {
	var mobileMessagingInstance: MobileMessagingInstance {
		return MobileMessagingInstance.sharedInstance
	}
	
	var storage: MMCoreDataStorage {
		return mobileMessagingInstance.storage!
	}
	
	override func setUp() {
		super.setUp()
		MobileMessaging.testStartWithCorrectApplicationCode()
	}
	
	override func tearDown() {
		super.tearDown()
		MobileMessaging.stop()
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
}