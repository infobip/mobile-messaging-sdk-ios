//
//  MMInboxFilterOptionsTests.swift
//  MobileMessagingExample
//
//  Created by Ivan Kresic on 19.03.2024..
//  Copyright © 2024 CocoaPods. All rights reserved.
//

import XCTest
@testable import MobileMessaging

class MMInboxFilterOptionsTests: XCTestCase {
    
    
    
    func testJsonDecodingMultipleMessages() {
        let jsonstring = """
        {
            "fromDateTime": "2024-03-11T12:00:00+01:00",
            "toDateTime": "2024-03-20T12:00:00+01:00",
            "topic": "test",
            "limit": 10
        }
        """
        
        let jsonDict = JSON.parse(jsonstring).dictionaryObject;
        XCTAssertNotNil(jsonDict)
        
        let filterOptions = MMInboxFilterOptions(dictRepresentation: jsonDict!)
        
        XCTAssertEqual(filterOptions.fromDateTime, DateStaticFormatters.ISO8601SecondsFormatter.date(from: "2024-03-11T12:00:00+01:00"))
        XCTAssertEqual(filterOptions.toDateTime, DateStaticFormatters.ISO8601SecondsFormatter.date(from: "2024-03-20T12:00:00+01:00"))
        XCTAssertEqual(filterOptions.topic, "test")
        XCTAssertEqual(filterOptions.limit, 10)
    }
    
    func testJsonDecodingMessageFields() {
        let jsonstring = """
        {
            "fromDateTime": null,
            "toDateTime": null,
            "topic": null,
            "limit": null
        }
        """
       
        let jsonDict = JSON.parse(jsonstring).dictionaryObject;
        XCTAssertNotNil(jsonDict)
        
        let filterOptions = MMInboxFilterOptions(dictRepresentation: jsonDict!)
        
        XCTAssertEqual(filterOptions.fromDateTime, nil)
        XCTAssertEqual(filterOptions.toDateTime, nil)
        XCTAssertEqual(filterOptions.topic, nil)
        XCTAssertEqual(filterOptions.limit, nil)
    }
    

    func testFromDateTimeNotEmpty() {
        let jsonstring = """
        {
            "fromDateTime": "2024-03-11T12:00:00+01:00"
        }
        """
       
        let jsonDict = JSON.parse(jsonstring).dictionaryObject;
        XCTAssertNotNil(jsonDict)
        
        let filterOptions = MMInboxFilterOptions(dictRepresentation: jsonDict!)
        
        XCTAssertEqual(filterOptions.fromDateTime, DateStaticFormatters.ISO8601SecondsFormatter.date(from: "2024-03-11T12:00:00+01:00"))
        XCTAssertEqual(filterOptions.toDateTime, nil)
        XCTAssertEqual(filterOptions.topic, nil)
        XCTAssertEqual(filterOptions.limit, nil)
    }
    
    func testToDateTimeNotEmpty() {
        let jsonDictionary : [String : Any] = [
            "fromDateTime": NSNull(),
            "toDateTime": "2024-03-20T12:00:00+01:00",
            "topic": NSNull(),
            "limit": NSNull()
        ]
        
        let filterOptions = MMInboxFilterOptions(dictRepresentation: jsonDictionary)
        print(filterOptions)
        
        XCTAssertEqual(filterOptions.fromDateTime, nil)
        XCTAssertEqual(filterOptions.toDateTime, DateStaticFormatters.ISO8601SecondsFormatter.date(from: "2024-03-20T12:00:00+01:00"))
        XCTAssertEqual(filterOptions.topic, nil)
        XCTAssertEqual(filterOptions.limit, nil)
    }
    
    func testTopicNotNil() {
        let jsonDictionary : [String : Any] = [
             "fromDateTime": NSNull(),
             "toDateTime": NSNull(),
             "topic": "test",
             "limit": NSNull()
         ]
        
        let filterOptions = MMInboxFilterOptions(dictRepresentation: jsonDictionary)
        
        XCTAssertEqual(filterOptions.fromDateTime, nil)
        XCTAssertEqual(filterOptions.toDateTime, nil)
        XCTAssertEqual(filterOptions.topic, "test")
        XCTAssertEqual(filterOptions.limit, nil)
    }
    
    func testLimitNotNil() {
        let jsonDictionary : [String : Any] = [
             "fromDateTime": NSNull(),
             "toDateTime": NSNull(),
             "topic": NSNull(),
             "limit": 10
         ]
        
        let filterOptions = MMInboxFilterOptions(dictRepresentation: jsonDictionary)
        
        print(filterOptions)
        
        XCTAssertEqual(filterOptions.fromDateTime, nil)
        XCTAssertEqual(filterOptions.toDateTime, nil)
        XCTAssertEqual(filterOptions.topic, nil)
        XCTAssertEqual(filterOptions.limit, 10)
    }
}
