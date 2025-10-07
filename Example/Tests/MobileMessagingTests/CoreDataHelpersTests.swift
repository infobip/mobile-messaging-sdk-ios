// 
//  Example/Tests/MobileMessagingTests/CoreDataHelpersTests.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import XCTest
@testable import MobileMessaging

func date(withDay d: Int) -> NSDate {
	var comps = DateComponents()
	comps.day = d
	comps.calendar = Calendar(identifier: Calendar.Identifier.gregorian)
	return NSDate(timeIntervalSince1970: comps.date!.timeIntervalSince1970)
}

class CoreDataHelpersTests: MMTestCase {
    func testFetchingLimits() {
        MMTestCase.startWithCorrectApplicationCode()
        
		let ctx = self.storage.mainThreadManagedObjectContext!
		let summaryMessagesNumber = 100
		let fetchLimit = 10
		let notOlderThanDay = 30
		
		for i in 0..<summaryMessagesNumber {
			let newMsg = MessageManagedObject.MM_createEntityInContext(context: ctx)
			newMsg.creationDate = date(withDay: i+1) as Date
		}
		let resultsAll = MessageManagedObject.MM_findAllInContext(ctx)
		XCTAssertEqual(resultsAll?.count, summaryMessagesNumber)
		
		let resultsLimited = MessageManagedObject.MM_find(withPredicate: NSPredicate(format: "creationDate < %@", date(withDay: notOlderThanDay)), fetchLimit: fetchLimit, sortedBy: "creationDate", ascending: false, inContext: ctx)
		
		XCTAssertEqual(resultsLimited?.count, fetchLimit)
		
		let mostRecentMsg = resultsLimited?.first!
		XCTAssertEqual(mostRecentMsg?.creationDate, date(withDay: notOlderThanDay-1) as Date)
        
        waitForExpectations(timeout: 30, handler: nil)
    }
}
