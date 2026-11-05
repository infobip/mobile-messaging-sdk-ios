// 
//  Example/Tests/MobileMessagingTests/MMInboxFilterOptionsTests.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
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
    
    func testCursorInitializer() {
        let filterOptions = MMInboxFilterOptions(fromDateTime: nil, toDateTime: nil, topic: "sports", limit: 10, cursor: "c1")
        
        XCTAssertEqual(filterOptions.topic, "sports")
        XCTAssertNil(filterOptions.topics)
        XCTAssertEqual(filterOptions.limit, 10)
        XCTAssertEqual(filterOptions.cursor, "c1")
    }
    
    func testExistingInitializersHaveNoCursor() {
        XCTAssertNil(MMInboxFilterOptions(fromDateTime: nil, toDateTime: nil, topic: "sports", limit: 10).cursor)
        XCTAssertNil(MMInboxFilterOptions(fromDateTime: nil, toDateTime: nil, topics: ["sports"], limit: 10).cursor)
    }
    
    func testCursorFromDictionaryWithTopic() {
        let filterOptions = MMInboxFilterOptions(dictRepresentation: ["topic": "sports", "cursor": "c1"])
        
        XCTAssertEqual(filterOptions.topic, "sports")
        XCTAssertEqual(filterOptions.cursor, "c1")
    }
    
    func testCursorFromDictionaryIsKeptWithTopics() {
        let filterOptions = MMInboxFilterOptions(dictRepresentation: ["topics": ["sports"], "cursor": "c1"])
        
        XCTAssertEqual(filterOptions.topics, ["sports"])
        XCTAssertEqual(filterOptions.cursor, "c1")
    }
    
    func testCursorFromDictionaryWithEmptyTopics() {
        let filterOptions = MMInboxFilterOptions(dictRepresentation: ["topics": [String](), "cursor": "c1"])
        
        XCTAssertEqual(filterOptions.topics, [])
        XCTAssertEqual(filterOptions.cursor, "c1")
    }
    
    func testBlankCursorsAreNormalizedByEveryInitializer() {
        for cursor in [nil, "", " ", "\t\n"] as [String?] {
            let options = MMInboxFilterOptions(fromDateTime: nil, toDateTime: nil, topic: "Offers", limit: 5, cursor: cursor)
            XCTAssertNil(options.cursor)
            for filters: [String: Any] in [["topic": "Offers"], ["topics": ["Offers"]], ["topics": [String]()]] {
                var dictionary = filters
                dictionary["cursor"] = cursor
                XCTAssertNil(MMInboxFilterOptions(dictRepresentation: dictionary).cursor)
                dictionary["cursor"] = NSNull()
                XCTAssertNil(MMInboxFilterOptions(dictRepresentation: dictionary).cursor)
            }
        }
    }

    func testNonblankCursorIsPreservedExactlyByEveryInitializer() {
        let cursor = "  opaque+/=& cursor  "
        let options = MMInboxFilterOptions(fromDateTime: nil, toDateTime: nil, topic: "Offers", limit: 5, cursor: cursor)
        XCTAssertEqual(options.cursor, cursor)
        for filters: [String: Any] in [["topic": "Offers"], ["topics": ["Offers"]], ["topics": [String]()]] {
            var dictionary = filters
            dictionary["cursor"] = cursor
            XCTAssertEqual(MMInboxFilterOptions(dictRepresentation: dictionary).cursor, cursor)
        }
    }

    func testTopicTakesPrecedenceOverTopicsInDictionary() {
        for topics in [["news", "sports"], ["news"], []] {
            let filterOptions = MMInboxFilterOptions(dictRepresentation: ["topic": "sports", "topics": topics, "limit": 5, "cursor": "c1"])
            XCTAssertEqual(filterOptions.topic, "sports")
            XCTAssertNil(filterOptions.topics)
            XCTAssertEqual(filterOptions.limit, 5)
            XCTAssertEqual(filterOptions.cursor, "c1")
        }
        // A null topic does not take precedence.
        let filterOptions = MMInboxFilterOptions(dictRepresentation: ["topic": NSNull(), "topics": ["news"]])
        XCTAssertNil(filterOptions.topic)
        XCTAssertEqual(filterOptions.topics, ["news"])
    }

    func testMissingCursorFromDictionary() {
        XCTAssertNil(MMInboxFilterOptions(dictRepresentation: ["topic": "sports"]).cursor)
    }
}
