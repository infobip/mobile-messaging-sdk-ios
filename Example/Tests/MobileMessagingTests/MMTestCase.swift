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
        var result: MobileMessaging? = nil
        result = MobileMessaging.sharedInstance
        return result!
    }
    
    var storage: MMCoreDataStorage {
        var result: MMCoreDataStorage? = nil
        result = self.mobileMessagingInstance.internalStorage
        return result!
    }
    
    override func setUp() {
        super.setUp()
        MobileMessaging.logger.logOutput = .None
        MobileMessaging.logger.logLevel = .Off
        MobileMessaging.stop(true)
        startWithCorrectApplicationCode()
    }
    
    func cleanUpAndStop() {
        MobileMessaging.stop(true)
    }
    
    override func tearDown() {
        super.tearDown()
		self.cleanUpAndStop()
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
