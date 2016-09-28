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

let queue = MMQueue.Serial.newQueue("com.infobip.tests")

class MMTestCase: XCTestCase {
	var mobileMessagingInstance: MobileMessaging {
		var result: MobileMessaging? = nil
		queue.executeSync { result = MobileMessaging.sharedInstance }
		return result!
	}
	
	var storage: MMCoreDataStorage {
		var result: MMCoreDataStorage? = nil
		queue.executeSync { result = self.mobileMessagingInstance.storage }
		return result!
	}
	
	override func setUp() {
		queue.executeSync {
			super.setUp()
			MobileMessaging.logger.logOutput = .Console
			MobileMessaging.logger.logLevel = .All
			MobileMessaging.stop(true)
			self.startWithCorrectApplicationCode()
		}
	}
	
	func cleanUpAndStop() {
		queue.executeSync {
			self.mobileMessagingInstance.cleanUpAndStop()
		}
	}
	
	override func tearDown() {
		queue.executeSync {
			super.tearDown()
			self.cleanUpAndStop()
		}
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
		queue.executeSync {
			MobileMessaging.withApplicationCode(code, notificationType: .None).withBackendBaseURL(MMTestConstants.kTestBaseURLString).start()
		}
	}
	
	func startWithCorrectApplicationCode() {
		queue.executeSync {
			MobileMessaging.withApplicationCode(MMTestConstants.kTestCorrectApplicationCode, notificationType: .None).withBackendBaseURL(MMTestConstants.kTestBaseURLString).start()
		}
	}
	
	func startWithWrongApplicationCode() {
		queue.executeSync {
			MobileMessaging.withApplicationCode(MMTestConstants.kTestWrongApplicationCode, notificationType: .None).withBackendBaseURL(MMTestConstants.kTestBaseURLString).start()
		}
	}
}