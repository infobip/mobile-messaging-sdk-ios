//
//  SyncMessagesTest.swift
//  MobileMessaging
//
//  Created by okoroleva on 21.03.16.
//  Copyright © 2016 Infobip. All rights reserved.
//

import XCTest

@testable import MobileMessaging

struct SyncTestAppIds {
    static let kCorrectIdNothingToSynchronize = "CorrectIdNothingToSynchronize"
    static let kCorrectIdMergeSynchronization = "CorrectIdMergeSynchronization"
}

class SyncMessagesTest: XCTestCase {
    
    let storage = IBMMCoreDataStorage.inMemoryStorage

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
        
        let storage = IBMMCoreDataStorage.inMemoryStorage
        let ctx = storage.mainThreadManagedObjectContext
        Installation.MR_deleteAllMatchingPredicate(NSPredicate(value: true), inContext: ctx)
        DeliveryReport.MR_deleteAllMatchingPredicate(NSPredicate(value: true), inContext: ctx)

        ctx?.MR_saveOnlySelfAndWait()
        
        IBMobileMessaging.stop()
    }
    
    /**Conditions:
    1. Empty DB
    2. synchronization request was sent
    3. empty mIds response received
     
     Expected result:
     nothing changed in DB
    */
    func testNothingToSynchronize() {
        let expectation = expectationWithDescription("Synchronize response received")
        let syncCompletionExp = expectationWithDescription("Sync completed")
        
        checkDeliveryReportsInStorage(0)
        
        let remoteAPI = TestIBMMRemoteAPI(baseURLString: IBMMAPIValues.kTestBaseURLString,
                                          appCode: SyncTestAppIds.kCorrectIdNothingToSynchronize) { (response) -> Void in
                switch response {
                case .Success:
                    MMLogInfo("Success")
                case .Failure(let error):
                    XCTAssert(error == nil, "Synchronize messages request failed with error: \(error)")
                }
        
                expectation.fulfill()
        }
        
        let syncService = IBMMSyncMessagesService(storage: storage, remoteAPI: remoteAPI)
        syncService.sync { (messageIds, error) -> Void in
            XCTAssert(messageIds?.count == 0, "Unexpected messages synchronized \(messageIds)")
            XCTAssert(error == nil, "Unexpected error \(error)")
            self.checkDeliveryReportsInStorage(0)
            syncCompletionExp.fulfill()
        }
        
        waitForExpectationsWithTimeout(50) { (error) -> Void in
        }
    }

    /** Conditions:
     1. m1(delivery sent), m2(delivery not sent) - are in DB
     2. synchronization request was sent
     3. m1, m3, m4 response received
     
     Expected result:
     m3, m4 (delivery not sent) are in DB
     */
    func testMergeOldMessageIdsWithNew() {
        
        let expectation = expectationWithDescription("Synchronize response received")
        let dbExpectation = expectationWithDescription("DB synchronized")
        
        let storage = IBMMCoreDataStorage.inMemoryStorage
        let ctx = storage.mainThreadManagedObjectContext
        let m1Report = DeliveryReport.MR_createEntityInContext(ctx)
        m1Report.messageId = "m1"
        m1Report.reportSent = true
        m1Report.creationDate = NSDate()
        
        let m2Report = DeliveryReport.MR_createEntityInContext(ctx)
        m2Report.messageId = "m2"
        m2Report.reportSent = false
        m2Report.creationDate = NSDate()
        
        ctx?.MR_saveOnlySelfAndWait()
        
        let remoteAPI = TestIBMMRemoteAPI(baseURLString: IBMMAPIValues.kTestBaseURLString,
                                        appCode: SyncTestAppIds.kCorrectIdMergeSynchronization) { (response) -> Void in
                switch response {
                case .Success:
                    MMLogInfo("Success")
                case .Failure(let error):
                    XCTAssert(error == nil, "Synchronize messages request failed with error: \(error)")
                }

                expectation.fulfill()
                                            
                let delay2 = dispatch_time(DISPATCH_TIME_NOW, Int64(1 * Double(NSEC_PER_SEC)))
                dispatch_after(delay2, dispatch_get_main_queue()) {
                    if let reportsAfterSync = DeliveryReport.MR_findAllInContext(ctx) as? [DeliveryReport] {
                        let mIdsToCheck = Set(reportsAfterSync.map{$0.messageId})
                        let mIds = Set(["m1", "m2", "m3", "m4"])
                        let diff = mIdsToCheck.exclusiveOr(mIds)
                        XCTAssert(diff.isEmpty, "Not Expected mIds in DB: \(diff)")
                        
                        dbExpectation.fulfill()
                    }
                }
        }
        
        let delay1 = dispatch_time(DISPATCH_TIME_NOW, Int64(5 * Double(NSEC_PER_SEC)))
        dispatch_after(delay1, dispatch_get_main_queue()) {
            let syncService = IBMMSyncMessagesService(storage: storage, remoteAPI: remoteAPI)
            syncService.sync {(messageIds, error) -> Void in}
        }
        
        waitForExpectationsWithTimeout(50) { (error) -> Void in
        }
    }
    
    //MARK: heplers
    private func checkDeliveryReportsInStorage(expectedCount: Int) {
        let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(1 * Double(NSEC_PER_SEC)))
        dispatch_after(delayTime, dispatch_get_main_queue()) {
            let storage = IBMMCoreDataStorage.inMemoryStorage
            let storedReports = DeliveryReport.MR_findAllInContext(storage.mainThreadManagedObjectContext)
            XCTAssertEqual(storedReports.count, expectedCount, "Unexpected count of stored delivery reports : \(storedReports.count)")
        }
    }
}