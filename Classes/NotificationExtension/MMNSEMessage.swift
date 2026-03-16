//
//  MMNSEMessage.swift
//  MobileMessagingNotificationExtension
//
//  Copyright (c) 2016-2026 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

struct MMNSEMessage {
    let messageId: String
    let contentUrl: String?
    let originalPayload: [String: Any]
    var isDeliveryReportSent: Bool
    var deliveryReportedDate: Date?

    init?(payload: [String: Any]) {
        guard let messageId = payload[MMNSEConsts.APNSPayloadKeys.messageId] as? String,
              payload[MMNSEConsts.APNSPayloadKeys.aps] != nil
        else {
            return nil
        }

        self.messageId = messageId
        self.originalPayload = payload

        if let internalData = payload[MMNSEConsts.APNSPayloadKeys.internalData] as? [String: Any],
           let atts = internalData[MMNSEConsts.InternalDataKeys.attachments] as? [[String: Any]],
           let firstAtt = atts.first {
            self.contentUrl = firstAtt[MMNSEConsts.Attachments.Keys.url] as? String
        } else {
            self.contentUrl = nil
        }

        self.isDeliveryReportSent = false
        self.deliveryReportedDate = nil
    }

    static func isCorrectPayload(_ payload: [String: Any]) -> Bool {
        return MMNSEMessage(payload: payload) != nil
    }
}
