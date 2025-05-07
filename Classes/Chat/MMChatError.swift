//
//  MMChatError.swift
//  MobileMessaging
//
//  Created by Francisco Fortes on 11/09/2023.
//

import Foundation

public let MMChatErrorDomain = "com.inappchat"

public enum MMChatError: Error {
    case messageLengthExceeded(UInt),
         attachmentSizeExceeded(UInt),
         wrongPayload

    fileprivate var errorCode: Int {
        switch self {
        case .messageLengthExceeded:
            return 0
        case .attachmentSizeExceeded:
            return 1
        case .wrongPayload:
            return 2
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
