//
//  ManagedObjectObserverTests.swift
//  MobileMessagingExample
//
//  Created by Andrey K. on 09/06/16.
//

import XCTest
@testable import MobileMessaging
import CoreData
class ManagedObjectObserverTests: MMTestCase {

    override func setUp() {
        super.setUp()
		if let ctx = storage.mainThreadManagedObjectContext {
			let msg1 = MessageManagedObject.MM_createEntityInContext(context: ctx)
			msg1.messageId = "1.1"
			
			let msg2 = MessageManagedObject.MM_createEntityInContext(context: ctx)
			msg2.messageId = "2.1"
			ctx.MM_saveToPersistentStoreAndWait()
		}
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testThatChangeHandlerTriggerred() {
		weak var expectation1 = expectationWithDescription("Message 1 observed")
		weak var expectation2 = expectationWithDescription("Message 2 observed")
		
		if	let ctx = storage.mainThreadManagedObjectContext,
			let msg1 = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageId == %@", "1.1"), inContext: ctx)!.first as? MessageManagedObject,
			let msg2 = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageId == %@", "2.1"), inContext: ctx)!.first as? MessageManagedObject {
			
			let observingKeyPath = "messageId"
			let msg1newId = "1.2"
			let msg2newId = "2.2"
			
			ManagedObjectNotificationCenter.defaultCenter.addObserver(self, observee: msg1, forKeyPath: observingKeyPath, handler: { (keyPath, newValue) in
				XCTAssertEqual(newValue as? String, msg1newId, "The new value must be passed to handler")
				XCTAssertEqual(keyPath, observingKeyPath, "The keypath should be that particluar one which we are observing")
				expectation1?.fulfill()
			})
			
			ManagedObjectNotificationCenter.defaultCenter.addObserver(self, observee: msg2, forKeyPath: observingKeyPath, handler: { (keyPath, newValue) in
				XCTAssertEqual(newValue as? String, msg2newId, "The new value must be passed to handler")
				XCTAssertEqual(keyPath, observingKeyPath, "The keypath should be that particluar one which we are observing")
				expectation2?.fulfill()
			})

			msg1.messageId = msg1newId
			msg2.messageId = msg2newId
			ctx.MM_saveToPersistentStoreAndWait()
			
		} else {
			XCTFail()
		}
		
		waitForExpectationsWithTimeout(2, handler: nil)
    }
	
	func testThatChangeHandlerNotTriggerred() {
		weak var expectation = expectationWithDescription("Test finished")
		if let ctx = storage.mainThreadManagedObjectContext, let msg = MessageManagedObject.MM_findFirstInContext(context: ctx){
			let observingKeyPath = "creationDate"
			
			ManagedObjectNotificationCenter.defaultCenter.addObserver(self, observee: msg, forKeyPath: observingKeyPath, handler: { (keyPath, newValue) in
				XCTFail("Handler must not be triggered, because we changed different key")
			})
			
			msg.messageId = "2"
			ctx.MM_saveToPersistentStoreAndWait()
		} else {
			XCTFail()
		}
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.5 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
			expectation?.fulfill()
		}
		waitForExpectationsWithTimeout(2, handler: nil)
	}
	
	func testThatRemovedObserverNotTriggerred() {
		weak var expectation = expectationWithDescription("Test finished")
		if let ctx = storage.mainThreadManagedObjectContext, let msg = MessageManagedObject.MM_findFirstInContext(context: ctx){
			do {
				let observingKeyPath = "messageId"
				ManagedObjectNotificationCenter.defaultCenter.addObserver(self, observee: msg, forKeyPath: observingKeyPath, handler: { (keyPath, newValue) in
					XCTFail("Handler must not be triggered, because we removed the observer")
				})
				ManagedObjectNotificationCenter.defaultCenter.removeObserver(self, observee: msg, forKeyPath: observingKeyPath)
				msg.messageId = "2"
				ctx.MM_saveToPersistentStoreAndWait()
			}
			do {
				let observingKeyPath = "messageId"
				ManagedObjectNotificationCenter.defaultCenter.addObserver(self, observee: msg, forKeyPath: observingKeyPath, handler: { (keyPath, newValue) in
					XCTFail("Handler must not be triggered, because we removed the observer")
				})
				ManagedObjectNotificationCenter.defaultCenter.removeAllObservers()
				msg.messageId = "2"
				ctx.MM_saveToPersistentStoreAndWait()
			}
		} else {
			XCTFail()
		}
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.5 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
			expectation?.fulfill()
		}
		waitForExpectationsWithTimeout(2, handler: nil)
	}
	
	func testObservationsNotDuplicated() {
		if let ctx = storage.mainThreadManagedObjectContext, let msg = MessageManagedObject.MM_findFirstInContext(context: ctx){
			var observationsCounter = 0
			weak var expectation = expectationWithDescription("Test finished")
			let observingKeyPath = "messageId"
			
			ManagedObjectNotificationCenter.defaultCenter.addObserver(self, observee: msg, forKeyPath: observingKeyPath, handler: { (keyPath, newValue) in
				observationsCounter += 1
			})
			
			ManagedObjectNotificationCenter.defaultCenter.addObserver(self, observee: msg, forKeyPath: observingKeyPath, handler: { (keyPath, newValue) in
				observationsCounter += 1
			})
			
			msg.messageId = "2"
			ctx.MM_saveToPersistentStoreAndWait()
			
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.5 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
				expectation?.fulfill()
			}
			waitForExpectationsWithTimeout(1) { error in
				XCTAssertEqual(observationsCounter, 1, "Observations must not duplicate")
			}
		} else {
			XCTFail()
		}
	}
	
	func testThatStopServiceResets() {
		
		if let msg = MessageManagedObject.MM_findFirstInContext(context: storage.mainThreadManagedObjectContext!){
			weak var expectation = expectationWithDescription("Test finished")
			
			let observingKeyPath = "messageId"
			ManagedObjectNotificationCenter.defaultCenter.addObserver(self, observee: msg, forKeyPath: observingKeyPath, handler: { (keyPath, newValue) in
				XCTFail("Handler must not be triggered, because we removed the observer")
			})
			
			// restart
			mobileMessagingInstance.cleanUpAndStop()
			startWithCorrectApplicationCode()
			
			let ctx = storage.mainThreadManagedObjectContext!
			let msg2 = MessageManagedObject.MM_createEntityInContext(context: ctx)
			msg2.messageId = "2.1"
			ctx.MM_saveToPersistentStoreAndWait()
	
			ManagedObjectNotificationCenter.defaultCenter.addObserver(self, observee: msg2, forKeyPath: observingKeyPath, handler: { (keyPath, newValue) in
				expectation?.fulfill()
			})
		
			msg2.messageId = "3"
			ctx.MM_saveToPersistentStoreAndWait()
			
			waitForExpectationsWithTimeout(2, handler: nil)
			
		} else {
			XCTFail()
		}
	}
}