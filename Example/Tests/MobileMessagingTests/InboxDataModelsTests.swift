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
    
    func testNextCursorDecoding() {
        let withCursor = MMInbox(json: JSON.parse("""
        { "messages": [], "countTotal": 30, "countUnread": 5, "nextCursor": "eyJ2IjoxfQ" }
        """))
        XCTAssertEqual(withCursor?.nextCursor, "eyJ2IjoxfQ")
        
        let withoutCursor = MMInbox(json: JSON.parse("""
        { "messages": [], "countTotal": 30, "countUnread": 5 }
        """))
        XCTAssertNotNil(withoutCursor)
        XCTAssertNil(withoutCursor?.nextCursor)
        
        let nullCursor = MMInbox(json: JSON.parse("""
        { "messages": [], "countTotal": 30, "countUnread": 5, "nextCursor": null }
        """))
        XCTAssertNotNil(nullCursor)
        XCTAssertNil(nullCursor?.nextCursor)
    }
    
    func testMemberwiseInitializers() {
        let inbox = MMInbox(messages: [], countTotal: 1, countUnread: 0, countTotalFiltered: nil, countUnreadFiltered: nil)
        XCTAssertNil(inbox.nextCursor)
        
        let inboxWithCursor = MMInbox(messages: [], countTotal: 1, countUnread: 0, countTotalFiltered: nil, countUnreadFiltered: nil, nextCursor: "c1")
        XCTAssertEqual(inboxWithCursor.nextCursor, "c1")
    }

    func testBlankNextCursorsAreNormalizedAndOmittedFromPluginDictionary() throws {
        for cursor in ["", " ", "\t\n", "\u{00a0}"] {
            let decoded = try XCTUnwrap(MMInbox(json: JSON([
                "messages": [], "countTotal": 30, "countUnread": 5, "nextCursor": cursor
            ])))
            let constructed = MMInbox(messages: [], countTotal: 30, countUnread: 5, countTotalFiltered: nil, countUnreadFiltered: nil, nextCursor: cursor)
            for inbox in [decoded, constructed] {
                XCTAssertNil(inbox.nextCursor, "A blank response cursor must end pagination instead of restarting the first page")
                XCTAssertNil(inbox.dictionaryRepresentation["nextCursor"])
            }
        }
    }

    func testNonblankNextCursorsArePreservedExactly() throws {
        for cursor in ["c1", "  opaque+/=& cursor\t\n"] {
            let decoded = try XCTUnwrap(MMInbox(json: JSON([
                "messages": [], "countTotal": 30, "countUnread": 5, "nextCursor": cursor
            ])))
            let constructed = MMInbox(messages: [], countTotal: 30, countUnread: 5, countTotalFiltered: nil, countUnreadFiltered: nil, nextCursor: cursor)
            for inbox in [decoded, constructed] {
                XCTAssertEqual(inbox.nextCursor, cursor)
                XCTAssertEqual(inbox.dictionaryRepresentation["nextCursor"] as? String, cursor)
            }
        }
    }

    func testPluginDictionaryIncludesCursorCountersAndExistingMessageFormat() throws {
        let inbox = try XCTUnwrap(MMInbox(json: JSON.parse("""
        {
            "messages": [{
                "messageId": "message-1",
                "aps": {"alert": {"title": "Offer", "body": "Message text"}},
                "internalData": {"sendDateTime": 1643314503233, "inbox": {"topic": "Offers", "seen": true}}
            }],
            "countTotal": 10,
            "countUnread": 3,
            "countTotalFiltered": 2,
            "countUnreadFiltered": 0,
            "nextCursor": "  opaque+/=& cursor  "
        }
        """)))
        let dictionary = inbox.dictionaryRepresentation
        XCTAssertEqual(dictionary["countTotal"] as? Int, 10)
        XCTAssertEqual(dictionary["countUnread"] as? Int, 3)
        XCTAssertEqual(dictionary["countTotalFiltered"] as? Int, 2)
        XCTAssertEqual(dictionary["countUnreadFiltered"] as? Int, 0)
        XCTAssertEqual(dictionary["nextCursor"] as? String, "  opaque+/=& cursor  ")
        let messages = try XCTUnwrap(dictionary["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 1)
        let message = try XCTUnwrap(inbox.messages.first)
        XCTAssertEqual(messages.first.map { NSDictionary(dictionary: $0) }, NSDictionary(dictionary: message.dictionaryRepresentation))

        // Bridges must be able to serialize the result without Swift Optional values or model objects.
        let data = try JSONSerialization.data(withJSONObject: dictionary)
        let decoded = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(decoded["nextCursor"] as? String, inbox.nextCursor)
        let decodedMessages = try XCTUnwrap(decoded["messages"] as? [[String: Any]])
        XCTAssertEqual(decodedMessages.first?["messageId"] as? String, "message-1")
        XCTAssertEqual(decodedMessages.first?["topic"] as? String, "Offers")
        XCTAssertEqual(decodedMessages.first?["seen"] as? Bool, true)
    }

    func testPluginDictionaryOmitsMissingAndNullOptionalFields() throws {
        for json in [
            "{\"messages\":[],\"countTotal\":0,\"countUnread\":0}",
            "{\"messages\":[],\"countTotal\":0,\"countUnread\":0,\"nextCursor\":null,\"countTotalFiltered\":null,\"countUnreadFiltered\":null}"
        ] {
            let inbox = try XCTUnwrap(MMInbox(json: JSON.parse(json)))
            let dictionary = inbox.dictionaryRepresentation
            XCTAssertEqual(Set(dictionary.keys), ["countTotal", "countUnread", "messages"])
            XCTAssertEqual(dictionary["countTotal"] as? Int, 0)
            XCTAssertEqual(dictionary["countUnread"] as? Int, 0)
            XCTAssertEqual((dictionary["messages"] as? [[String: Any]])?.count, 0)
            XCTAssertTrue(JSONSerialization.isValidJSONObject(dictionary))
        }
    }

    func testInboxCompletionApisAreExposedToObjectiveC() {
        XCTAssertTrue(MobileMessaging.responds(to: NSSelectorFromString("inbox")))
        XCTAssertTrue(MMInbox.instancesRespond(to: NSSelectorFromString("dictionaryRepresentation")))
        XCTAssertTrue(MMInboxFilterOptions.instancesRespond(to: NSSelectorFromString("initWithDictRepresentation:")))
        for selector in [
            "fetchInboxWithToken:externalUserId:options:completion:",
            "fetchInboxWithExternalUserId:options:completion:",
            "setSeenWithExternalUserId:messageIds:completion:",
            "deleteMessagesWithToken:externalUserId:messageIds:completionHandler:",
            "deleteMessagesWithExternalUserId:messageIds:completionHandler:"
        ] {
            XCTAssertTrue(MMInboxService.instancesRespond(to: NSSelectorFromString(selector)), selector)
        }
    }

}
