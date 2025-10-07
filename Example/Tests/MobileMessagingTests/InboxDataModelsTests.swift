// 
//  Example/Tests/MobileMessagingTests/InboxDataModelsTests.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import XCTest
@testable import MobileMessaging

class InboxDataModelsTests: XCTestCase {
    
    func testJsonDecodingMultipleMessages() {
        let jsonstring = """
{
  "messages": [
    {
      "messageId": "793fd94e-deda-4298-b41d-ee857d533e23",
      "internalData": {
        "campaignId": "7045f9f9-c971-4706-b8a6-63547b0360e5",
        "inApp": false,
        "sendDateTime": 1643314503233,
        "inbox": {
          "seen": true,
          "topic": "default"
        }
      },
      "aps": {
        "sound": "default",
        "alert": {
          "title": "Test",
          "body": "ygj"
        }
      },
      "silent": false
    },
    {
      "messageId": "9cd50e63-b986-46ce-8992-027fe5e41486",
      "internalData": {
        "campaignId": "362c6568-3ae1-4273-ba6f-ea170d3984b7",
        "inApp": false,
        "sendDateTime": 1643314503233,
        "inbox": {
          "topic": "default"
        }
      },
      "aps": {
        "sound": "default",
        "alert": {
          "title": "Test",
          "body": "vre"
        }
      },
      "silent": false
    }
  ],
  "countTotal": 2,
  "countUnread": 1
}
"""
        
        let inbox = MMInbox(json: JSON.parse(jsonstring))
        
        XCTAssertEqual(inbox!.countTotal, 2)
        XCTAssertEqual(inbox!.countUnread, 1)
        XCTAssertEqual(inbox!.messages.count, 2)
        XCTAssertNil(inbox!.countTotalFiltered)
        XCTAssertNil(inbox!.countUnreadFiltered)
    }
    
    func testJsonDecodingMessageFields() {
        let jsonstring = """
{
  "messages": [
    {
      "messageId": "793fd94e-deda-4298-b41d-ee857d533e23",
      "internalData": {
        "campaignId": "7045f9f9-c971-4706-b8a6-63547b0360e5",
        "inApp": false,
        "sendDateTime": 1643314503233,
        "inbox": {
          "seen": true,
          "topic": "default"
        }
      },
      "aps": {
        "sound": "default",
        "alert": {
          "title": "Test",
          "body": "ygj"
        }
      },
      "silent": false
    }
  ],
  "countTotal": 1,
  "countUnread": 0
}
"""
        
        let inbox = MMInbox(json: JSON.parse(jsonstring))
        let msg = inbox!.messages.first!
        XCTAssertEqual(msg.topic, "default")
        XCTAssertEqual(msg.text, "ygj")
        XCTAssertEqual(msg.title, "Test")
        XCTAssertEqual(msg.isSilent, false)
        XCTAssertEqual(msg.showInApp, false)
        XCTAssertEqual(msg.seenStatus, .SeenNotSent)
    }
    

    func testJsonDecodingWithFilteredCounts() {
        let jsonstring = """
{
  "messages": [
    {
      "messageId": "793fd94e-deda-4298-b41d-ee857d533e23",
      "internalData": {
        "campaignId": "7045f9f9-c971-4706-b8a6-63547b0360e5",
        "inApp": false,
        "sendDateTime": 1643314503233,
        "inbox": {
          "seen": true,
          "topic": "default"
        }
      },
      "aps": {
        "sound": "default",
        "alert": {
          "title": "Test",
          "body": "ygj"
        }
      },
      "silent": false
    }
  ],
  "countTotal": 10,
  "countUnread": 5,
  "countTotalFiltered": 3,
  "countUnreadFiltered": 1
}
"""
        
        let inbox = MMInbox(json: JSON.parse(jsonstring))
        
        XCTAssertEqual(inbox!.countTotal, 10)
        XCTAssertEqual(inbox!.countUnread, 5)
        XCTAssertEqual(inbox!.countTotalFiltered, 3)
        XCTAssertEqual(inbox!.countUnreadFiltered, 1)
        XCTAssertEqual(inbox!.messages.count, 1)
    }

    func testJsonDecodingWithMultipleTopicsFiltering() {
        let jsonstring = """
{
  "messages": [
    {
      "messageId": "msg1",
      "internalData": {
        "campaignId": "campaign1",
        "inApp": false,
        "sendDateTime": 1643314503233,
        "inbox": {
          "seen": false,
          "topic": "sports"
        }
      },
      "aps": {
        "sound": "default",
        "alert": {
          "title": "Sports News",
          "body": "Latest sports update"
        }
      },
      "silent": false
    },
    {
      "messageId": "msg2",
      "internalData": {
        "campaignId": "campaign2",
        "inApp": false,
        "sendDateTime": 1643314503234,
        "inbox": {
          "seen": true,
          "topic": "weather"
        }
      },
      "aps": {
        "sound": "default",
        "alert": {
          "title": "Weather Alert",
          "body": "Rain expected"
        }
      },
      "silent": false
    },
    {
      "messageId": "msg3",
      "internalData": {
        "campaignId": "campaign3",
        "inApp": false,
        "sendDateTime": 1643314503235,
        "inbox": {
          "seen": false,
          "topic": "news"
        }
      },
      "aps": {
        "sound": "default",
        "alert": {
          "title": "Breaking News",
          "body": "Important announcement"
        }
      },
      "silent": false
    }
  ],
  "countTotal": 10,
  "countUnread": 5
}
"""
        
        let serverInbox = MMInbox(json: JSON.parse(jsonstring))!
        let filteredTopics = ["sports", "weather"]
        
        let filteredMessages = serverInbox.messages.filter { message in
            guard let messageTopic = message.topic else {
                return false
            }
            return filteredTopics.contains(messageTopic)
        }
        
        let limitedMessages = Array(filteredMessages.prefix(2))
        
        let filteredInbox = MMInbox(
            messages: limitedMessages,
            countTotal: serverInbox.countTotal,
            countUnread: serverInbox.countUnread,
            countTotalFiltered: filteredMessages.count,
            countUnreadFiltered: filteredMessages.filter { $0.seenStatus == .NotSeen }.count
        )
        
        XCTAssertEqual(filteredInbox.messages.count, 2)
        XCTAssertEqual(filteredInbox.countTotal, 10)
        XCTAssertEqual(filteredInbox.countUnread, 5)
        XCTAssertEqual(filteredInbox.countTotalFiltered, 2) // 2 messages matched topics filter (before limit)
        XCTAssertEqual(filteredInbox.countUnreadFiltered, 1) // 1 unread message matched topics filter (before limit)
        
        let topicsInResult = filteredInbox.messages.compactMap { $0.topic }
        XCTAssertTrue(topicsInResult.contains("sports"))
        XCTAssertTrue(topicsInResult.contains("weather"))
        XCTAssertFalse(topicsInResult.contains("news"))
    }

    func testSeenRequestDataMapper() {
        let requestBody = InboxSeenRequestDataMapper.requestBody(messageIds: ["m1", "m2"], externalUserId: "123", seenDate: MMDate().now)
        
        let messages = (requestBody["messages"] as! Array<RequestBody>)
        XCTAssertEqual(requestBody["externalUserId"] as! String, "123")
        XCTAssertEqual(messages.count, 2)
        XCTAssertTrue(messages.allSatisfy { elem in
            return (elem["inbox"] as! Bool) == true
        })
        XCTAssertTrue(messages.contains(where: { elem in
            return (elem["messageId"] as! String) == "m1"
        }))
        XCTAssertTrue(messages.contains(where: { elem in
            return (elem["messageId"] as! String) == "m2"
        }))
    }
}
