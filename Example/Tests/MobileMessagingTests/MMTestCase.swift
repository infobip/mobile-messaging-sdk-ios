//
//  MMTestCase.swift
//  MobileMessaging
//
//  Created by Andrey K. on 16/04/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
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
	
	func nonReportedStoredMessagesCount(ctx: NSManagedObjectContext) -> UInt {
		var count: UInt = 0
		ctx.reset()
		ctx.performBlockAndWait {
			count = MessageManagedObject.MR_countOfEntitiesWithPredicate(NSPredicate(format: "reportSent == false"), inContext: ctx)
		}
		return count
	}
	
	func allStoredMessagesCount(ctx: NSManagedObjectContext) -> UInt {
		var count: UInt = 0
		ctx.reset()
		MMQueue.Main.queue.executeSync {
			count = MessageManagedObject.MR_countOfEntitiesWithContext(ctx)
		}
		return count
	}
}