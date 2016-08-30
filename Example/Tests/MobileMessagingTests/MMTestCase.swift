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
	var mobileMessagingInstance: MobileMessaging {
		return MobileMessaging.sharedInstance!
	}
	
	var storage: MMCoreDataStorage {
		return mobileMessagingInstance.storage!
	}
	
	override func setUp() {
		super.setUp()
		MobileMessaging.loggingUtil.setLoggingOptions([MMLoggingOptions.Console], logLevel: MMLogLevel.All)
		MobileMessaging.stop(true)
		startWithCorrectApplicationCode()
	}
	
	func cleanUpAndStop() {
		mobileMessagingInstance.cleanUpAndStop()
	}
	
	override func tearDown() {
		super.tearDown()
		cleanUpAndStop()
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
		MobileMessaging.withApplicationCode(code, notificationType: []).withBackendBaseURL(MMTestConstants.kTestBaseURLString).start()
	}
	
	func startWithCorrectApplicationCode() {
		MobileMessaging.withApplicationCode(MMTestConstants.kTestCorrectApplicationCode, notificationType: []).withBackendBaseURL(MMTestConstants.kTestBaseURLString).start()
	}
	
	func startWithWrongApplicationCode() {
		MobileMessaging.withApplicationCode(MMTestConstants.kTestWrongApplicationCode, notificationType: []).withBackendBaseURL(MMTestConstants.kTestBaseURLString).start()
	}
}
