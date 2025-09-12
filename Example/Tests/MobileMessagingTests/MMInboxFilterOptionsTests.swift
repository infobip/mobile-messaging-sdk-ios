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
    
    func testMultipleTopicsInitializer() {
        let topics = ["sports", "weather", "news"]
        let fromDate = Date()
        let toDate = Date().addingTimeInterval(3600)
        let limit = 20
        
        let filterOptions = MMInboxFilterOptions(
            fromDateTime: fromDate,
            toDateTime: toDate,
            topics: topics,
            limit: limit
        )
        
        XCTAssertEqual(filterOptions.fromDateTime, fromDate)
        XCTAssertEqual(filterOptions.toDateTime, toDate)
        XCTAssertNil(filterOptions.topic) // Should be nil when using topics array
        XCTAssertEqual(filterOptions.topics, topics)
        XCTAssertEqual(filterOptions.limit, limit)
    }
    
    func testMultipleTopicsFromDictionary() {
        let jsonDictionary : [String : Any] = [
            "fromDateTime": "2024-03-11T12:00:00+01:00",
            "toDateTime": "2024-03-20T12:00:00+01:00",
            "topics": ["sports", "weather", "news"],
            "limit": 15
        ]
        
        let filterOptions = MMInboxFilterOptions(dictRepresentation: jsonDictionary)
        
        XCTAssertEqual(filterOptions.fromDateTime, DateStaticFormatters.ISO8601SecondsFormatter.date(from: "2024-03-11T12:00:00+01:00"))
        XCTAssertEqual(filterOptions.toDateTime, DateStaticFormatters.ISO8601SecondsFormatter.date(from: "2024-03-20T12:00:00+01:00"))
        XCTAssertNil(filterOptions.topic) // Should be nil when using topics array
        XCTAssertEqual(filterOptions.topics, ["sports", "weather", "news"])
        XCTAssertEqual(filterOptions.limit, 15)
    }
    
    func testSingleTopicInitializer() {
        let topic = "sports"
        let fromDate = Date()
        let toDate = Date().addingTimeInterval(3600)
        let limit = 10
        
        let filterOptions = MMInboxFilterOptions(
            fromDateTime: fromDate,
            toDateTime: toDate,
            topic: topic,
            limit: limit
        )
        
        XCTAssertEqual(filterOptions.fromDateTime, fromDate)
        XCTAssertEqual(filterOptions.toDateTime, toDate)
        XCTAssertEqual(filterOptions.topic, topic)
        XCTAssertNil(filterOptions.topics) // Should be nil when using single topic
        XCTAssertEqual(filterOptions.limit, limit)
    }
    
    func testDictionaryFallsBackToSingleTopicWhenNoTopicsArray() {
        let jsonDictionary : [String : Any] = [
            "fromDateTime": "2024-03-11T12:00:00+01:00",
            "toDateTime": "2024-03-20T12:00:00+01:00",
            "topic": "sports",
            "limit": 5
        ]
        
        let filterOptions = MMInboxFilterOptions(dictRepresentation: jsonDictionary)
        
        XCTAssertEqual(filterOptions.fromDateTime, DateStaticFormatters.ISO8601SecondsFormatter.date(from: "2024-03-11T12:00:00+01:00"))
        XCTAssertEqual(filterOptions.toDateTime, DateStaticFormatters.ISO8601SecondsFormatter.date(from: "2024-03-20T12:00:00+01:00"))
        XCTAssertEqual(filterOptions.topic, "sports")
        XCTAssertNil(filterOptions.topics) // Should be nil when using single topic
        XCTAssertEqual(filterOptions.limit, 5)
    }
}
