//
//  WebInAppMessage.swift
//  MobileMessagingExample
//
//  Created by Davor Komusanac on 22.03.2023..
//

import Foundation
import XCTest
@testable import MobileMessaging

class MMInAppMessageTests: XCTestCase {
    func testThatMMInAppMessageIsNotNilWhenEverythingIsProvided() {
        let userInfo: MMAPNSPayload = [
            AnyHashable("messageId"): "random-message-id-123456",
            AnyHashable("aps"): ["alert": ["body": "msg_body"]],
            AnyHashable("internalData"):
                [
                    "inAppDetails": [
                        "position": 1,
                        "url": "https://www.infobip.com",
                        "type": 1
                    ]
                ],
            AnyHashable("silent"): true
        ]
        
        let msg = MMInAppMessage(payload: userInfo,
                                    deliveryMethod: .push,
                                    seenDate: nil,
                                    deliveryReportDate: nil,
                                    seenStatus: .NotSeen,
                                    isDeliveryReportSent: false)
        XCTAssertNotNil(msg)
    }
    
    func testThatMMInAppMessageIsNilWhenInternalDataIsMissing() {
        let userInfo: MMAPNSPayload = [
            AnyHashable("messageId"): "random-message-id-123456",
            AnyHashable("aps"): ["alert": ["body": "msg_body"]],
            AnyHashable("silent"): true
        ]
        
        let msg = MMInAppMessage(payload: userInfo,
                                    deliveryMethod: .push,
                                    seenDate: nil,
                                    deliveryReportDate: nil,
                                    seenStatus: .NotSeen,
                                    isDeliveryReportSent: false)
        XCTAssertNil(msg)
    }
    
    func testThatMMInAppMessageIsNilWhenInAppDetailsIsMissing() {
        let userInfo: MMAPNSPayload = [
            AnyHashable("messageId"): "random-message-id-123456",
            AnyHashable("aps"): ["alert": ["body": "msg_body"]],
            AnyHashable("internalData"):
                [],
            AnyHashable("silent"): true
        ]
        
        let msg = MMInAppMessage(payload: userInfo,
                                    deliveryMethod: .push,
                                    seenDate: nil,
                                    deliveryReportDate: nil,
                                    seenStatus: .NotSeen,
                                    isDeliveryReportSent: false)
        XCTAssertNil(msg)
    }
    
    func testThatMMInAppMessageIsNilWhenUrlIsMissing() {
        let userInfo: MMAPNSPayload = [
            AnyHashable("messageId"): "random-message-id-123456",
            AnyHashable("aps"): ["alert": ["body": "msg_body"]],
            AnyHashable("internalData"):
                [
                    "inAppDetails": [
                        "position": 1,
                        "type": 1
                    ]
                ],
            AnyHashable("silent"): true
        ]
        
        let msg = MMInAppMessage(payload: userInfo,
                                    deliveryMethod: .push,
                                    seenDate: nil,
                                    deliveryReportDate: nil,
                                    seenStatus: .NotSeen,
                                    isDeliveryReportSent: false)
        XCTAssertNil(msg)
    }
    
    func testThatMMInAppMessageIsNilWhenUrlIsInvalid() {
        let userInfo: MMAPNSPayload = [
            AnyHashable("messageId"): "random-message-id-123456",
            AnyHashable("aps"): ["alert": ["body": "msg_body"]],
            AnyHashable("internalData"):
                [
                    "inAppDetails": [
                        "position": 1,
                        "url": 123,
                        "type": 1
                    ]
                ],
            AnyHashable("silent"): true
        ]
        
        let msg = MMInAppMessage(payload: userInfo,
                                    deliveryMethod: .push,
                                    seenDate: nil,
                                    deliveryReportDate: nil,
                                    seenStatus: .NotSeen,
                                    isDeliveryReportSent: false)
        XCTAssertNil(msg)
    }
    
    func testThatMMInAppMessageIsNilWhenTypeIsMissing() {
        let userInfo: MMAPNSPayload = [
            AnyHashable("messageId"): "random-message-id-123456",
            AnyHashable("aps"): ["alert": ["body": "msg_body"]],
            AnyHashable("internalData"):
                [
                    "inAppDetails": [
                        "position": 1,
                        "url": "https://www.infobip.com"
                    ]
                ],
            AnyHashable("silent"): true
        ]
        
        let msg = MMInAppMessage(payload: userInfo,
                                    deliveryMethod: .push,
                                    seenDate: nil,
                                    deliveryReportDate: nil,
                                    seenStatus: .NotSeen,
                                    isDeliveryReportSent: false)
        XCTAssertNil(msg)
    }
    
    func testThatMMInAppMessageIsNilWhenTypeIsWrong() {
        let userInfo: MMAPNSPayload = [
            AnyHashable("messageId"): "random-message-id-123456",
            AnyHashable("aps"): ["alert": ["body": "msg_body"]],
            AnyHashable("internalData"):
                [
                    "inAppDetails": [
                        "position": 1,
                        "url": "https://www.infobip.com",
                        "type": 10
                    ]
                ],
            AnyHashable("silent"): true
        ]
        
        let msg = MMInAppMessage(payload: userInfo,
                                    deliveryMethod: .push,
                                    seenDate: nil,
                                    deliveryReportDate: nil,
                                    seenStatus: .NotSeen,
                                    isDeliveryReportSent: false)
        XCTAssertNil(msg)
    }
    
    func testThatMMInAppMessageIsNilWhenBannerPositionIsInvalid() {
        let userInfo: MMAPNSPayload = [
            AnyHashable("messageId"): "random-message-id-123456",
            AnyHashable("aps"): ["alert": ["body": "msg_body"]],
            AnyHashable("internalData"):
                [
                    "inAppDetails": [
                        "position": 5,
                        "url": "https://www.infobip.com",
                        "type": 0
                    ]
                ],
            AnyHashable("silent"): true
        ]
        
        let msg = MMInAppMessage(payload: userInfo,
                                    deliveryMethod: .push,
                                    seenDate: nil,
                                    deliveryReportDate: nil,
                                    seenStatus: .NotSeen,
                                    isDeliveryReportSent: false)
        XCTAssertNil(msg)
    }
    
    func testThatMMInAppMessageIsNilWhenBannerPositionIsMissing() {
        let userInfo: MMAPNSPayload = [
            AnyHashable("messageId"): "random-message-id-123456",
            AnyHashable("aps"): ["alert": ["body": "msg_body"]],
            AnyHashable("internalData"):
                [
                    "inAppDetails": [
                        "url": "https://www.infobip.com",
                        "type": 0
                    ]
                ],
            AnyHashable("silent"): true
        ]
        
        let msg = MMInAppMessage(payload: userInfo,
                                    deliveryMethod: .push,
                                    seenDate: nil,
                                    deliveryReportDate: nil,
                                    seenStatus: .NotSeen,
                                    isDeliveryReportSent: false)
        XCTAssertNil(msg)
    }
    
    func testThatMM_MTMessageIsCreatedWhenInAppDetailsIsMissing() {
        let userInfo: MMAPNSPayload = [
            AnyHashable("messageId"): "random-message-id-123456",
            AnyHashable("aps"): ["alert": ["body": "msg_body"]],
            AnyHashable("internalData"):
                [],
            AnyHashable("silent"): true
        ]
        
        let inAppMessage = MMInAppMessage(payload: userInfo,
                                    deliveryMethod: .push,
                                    seenDate: nil,
                                    deliveryReportDate: nil,
                                    seenStatus: .NotSeen,
                                    isDeliveryReportSent: false)
        
        XCTAssertTrue(inAppMessage == nil)
        
        let message = MM_MTMessage(payload: userInfo,
                           deliveryMethod: .push,
                           seenDate: nil,
                           deliveryReportDate: nil,
                           seenStatus: .NotSeen,
                           isDeliveryReportSent: false)
        
        XCTAssertTrue(message != nil)
    }
 }
