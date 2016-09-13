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
		MobileMessaging.logger.logOutput = .Console
		MobileMessaging.logger.logLevel = .All
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
		ctx.performBlockAndWait {
			count = MessageManagedObject.MM_countOfEntitiesWithContext(ctx)
		}
		return count
	}
	
	func startWithApplicationCode(code: String) {
		MobileMessaging.withApplicationCode(code, notificationType: .None).withBackendBaseURL(MMTestConstants.kTestBaseURLString).start()
	}
	
	func startWithCorrectApplicationCode() {
		MobileMessaging.withApplicationCode(MMTestConstants.kTestCorrectApplicationCode, notificationType: .None).withBackendBaseURL(MMTestConstants.kTestBaseURLString).start()
	}
	
	func startWithWrongApplicationCode() {
		MobileMessaging.withApplicationCode(MMTestConstants.kTestWrongApplicationCode, notificationType: .None).withBackendBaseURL(MMTestConstants.kTestBaseURLString).start()
	}
}