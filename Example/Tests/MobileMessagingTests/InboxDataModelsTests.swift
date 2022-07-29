//
//  InboxDataModelsTests.swift
//  MobileMessagingExample_Tests
//
//  Created by Andrey Kadochnikov on 01.03.2022.
//  Copyright © 2022 CocoaPods. All rights reserved.
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
