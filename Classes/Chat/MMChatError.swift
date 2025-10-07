// 
//  MMChatError.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

public let MMChatErrorDomain = "com.inappchat"

public enum MMChatError: Error {
    case messageLengthExceeded(UInt),
         attachmentSizeExceeded(UInt),
         wrongPayload,
         attachmentNotAllowed

    fileprivate var errorCode: Int {
        switch self {
        case .messageLengthExceeded:
            return -1
        case .attachmentSizeExceeded:
            return -2
        case .wrongPayload:
            return -3
        case .attachmentNotAllowed:
            return -4
        }
    }

    var userInfo: [String: String] {
        var errorDescription: String = ""

        switch self {
        case .messageLengthExceeded(let limit):
            errorDescription = "MMChatError: Message length exceeded: \(limit) characters"
        case .attachmentSizeExceeded(let limit):
            errorDescription = "MMChatError: Attachment size exceeded: \(limit) bytes"
        case .wrongPayload:
            errorDescription = "MMChatError: Incorrect payload values"
        case .attachmentNotAllowed:
            errorDescription = "MMChatError: Attachment uploading or file extension not allowed"
        }

        return [NSLocalizedDescriptionKey: errorDescription]
    }

    var foundationError: NSError {
        return NSError(chatError: self)
    }
}

extension NSError {
    public convenience init(chatError: MMChatError, chatPayload: MMLivechatPayload? = nil) {
        self.init(
            domain: MMChatErrorDomain,
            code: chatError.errorCode,
            userInfo: chatError.userInfo +  ["payload": chatPayload?.interfaceValue ?? ""])
    }
}
