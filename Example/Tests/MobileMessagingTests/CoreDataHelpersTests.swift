//
//  CoreDataHelpersTests.swift
//  MobileMessagingExample
//
//  Created by Andrey K. on 08/09/16.
//

import XCTest
@testable import MobileMessaging

func date(d: Int) -> NSDate {
	let comps = NSDateComponents()
	comps.day = d
	comps.calendar = NSCalendar(identifier: NSCalendarIdentifierGregorian)
	return comps.date!
}


class CoreDataHelpersTests: MMTestCase {
	
    func testExample() {
		let ctx = self.storage.mainThreadManagedObjectContext!
		let summaryMessagesNumber = 100
		let fetchLimit = 10
		let notOlderThanDay = 30
		
		for i in 0..<summaryMessagesNumber {
			let newMsg = MessageManagedObject.MM_createEntityInContext(context: ctx)
			newMsg.creationDate = date(i+1)
		}
		let resultsAll = MessageManagedObject.MM_findAllInContext(ctx)
		XCTAssertEqual(resultsAll?.count, summaryMessagesNumber)
		
		let resultsLimited = MessageManagedObject.MM_find(withPredicate: NSPredicate(format: "creationDate < %@", date(notOlderThanDay)), fetchLimit: fetchLimit, sortedBy: "creationDate", ascending: false, inContext: ctx) as? [MessageManagedObject]
		
		XCTAssertEqual(resultsLimited?.count, fetchLimit)
		
		let mostRecentMsg = resultsLimited?.first!
		XCTAssertEqual(mostRecentMsg?.creationDate, date(notOlderThanDay-1))
    }
}