// 
//  LiveChatAPI+Models.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

public struct MMLiveChatThread: Codable {
    public let id: String?
    public let conversationId: String?
    public let status: Status?

    public enum Status: String, Codable {
        case open = "OPEN"
        case solved = "SOLVED"
        case closed = "CLOSED"
        case unknown = "UNKNOWN"

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let statusString = try container.decode(String.self)

            switch statusString.uppercased() {
            case "OPEN":
                self = .open
            case "SOLVED":
                self = .solved
            case "CLOSED":
                self = .closed
            default:
                self = .unknown
            }
        }
    }
}

public enum MMLivechatMessageType: String, Encodable {
    case DRAFT, BASIC, CUSTOM_DATA
    var errorString: String {
        var methodName = ""
        switch self {
        case .DRAFT:
            methodName = "sendDraft"
        case .BASIC:
            methodName = "sendMessage"
        case .CUSTOM_DATA:
            methodName = "sendCustomData"
        }
        return "\(methodName) call got a response: %1$@, error: %2$@"
    }
}

public protocol MMLivechatPayload: Encodable {
    var type: MMLivechatMessageType { get }
    var interfaceValue: String { get }
    var threadId: String? { get set }
    var formattedThreadId: String { get }
}

public extension MMLivechatPayload {
    var formattedThreadId: String {
        guard let threadId = threadId else { return "" }
        return threadId.isEmpty ? "" : ", '\(threadId)'"
    }
}

public struct MMLivechatBasicPayload: MMLivechatPayload {
    public var type: MMLivechatMessageType { .BASIC }
    public var text: String?
    public private(set) var attachment: String?
    public private(set) var fileName: String?
    public private(set) var byteCount = 0
    var attachmentInfo: ChatMobileAttachment?
    public var threadId: String?
    public var interfaceValue: String {
        guard let text = text else {
            return """
            {
                'attachment': '\(attachment ?? "null")', 
                'fileName': '\(fileName ?? attachmentInfo?.fileName ?? UUID().uuidString)', 
                'type':'\(type)' 
            }\(formattedThreadId)
            """
        }

        return """
        {
            'message': \(text.javaScriptEscapedString() ?? "null"), 
            'type':'\(type)' 
        }\(formattedThreadId)
        """
    }

    public init(text: String? = nil, fileName: String? = nil, data: Data? = nil, threadId: String? = nil) {
        self.text = text
        self.threadId = threadId
        if let data = data {
            self.attachmentInfo = ChatMobileAttachment(fileName, data: data)
            self.byteCount = data.count
            self.attachment = "\(attachmentInfo?.base64UrlString() ?? "null")"
            self.fileName = fileName
        }
    }
}

public struct MMLivechatDraftPayload: MMLivechatPayload {
    public var type: MMLivechatMessageType { .DRAFT }
    public var text: String
    public var threadId: String?
    public var interfaceValue: String {
        return """
        {
            'message': \(text.javaScriptEscapedString() ?? "''"), 
            'type':'\(type)' 
        }\(formattedThreadId)
        """
    }
    public init(text: String, threadId: String? = nil) {
        self.text = text
        self.threadId = threadId
    }
}

public struct MMLivechatCustomPayload: MMLivechatPayload {
    public var type: MMLivechatMessageType { .CUSTOM_DATA }
    public var customData: String
    public var agentMessage: String?
    public var userMessage: String?
    public var threadId: String?
    public var interfaceValue: String {
        return """
        {
            'customData': \(customData), 
            'agentMessage':\(agentMessage?.javaScriptEscapedString() ?? "null"), 
            'userMessage':\(userMessage?.javaScriptEscapedString() ?? "null"), 
            'type':'\(type)'
        }\(formattedThreadId)
        """
    }
    public init(customData: String, agentMessage: String? = nil, userMessage: String? = nil, threadId: String? = nil) {
        self.customData = customData
        self.agentMessage = agentMessage
        self.userMessage = userMessage
        self.threadId = threadId
    }
}

public struct MMLivechatAPIError: Codable {
    let code: Int?
    let message: String?
    let name: String?
    let origin: String?
    let platform: String?
    var description: String {
        return """
            code: \(code ?? -1), 
            message:\(message ?? ""), 
            name: \(name ?? ""), 
            origin: \(origin ?? ""), 
            platform: \(platform ?? "")
        """
    }
}

struct MMLivechatMessageResponse: Codable {
    let success: Bool
    let error: MMLivechatAPIError?
    let data: MMLivechatMessageData?
}

struct MMLivechatMessageData: Codable {
    let thread: MMLiveChatThread?
}

public extension String {
    var livechatBasicPayload: MMLivechatBasicPayload {
        MMLivechatBasicPayload(text: self)
    }

    var livechatDraftPayload: MMLivechatDraftPayload {
        MMLivechatDraftPayload(text: self)
    }
}
