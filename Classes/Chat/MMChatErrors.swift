// 
//  MMChatErrors.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

public let MMChatLocalErrorDomain = "com.inappchat"

protocol MMChatThrowable {
    var localizedDescription: String { get }
    var exception: MMChatException { get }
}

internal enum MMChatAPIRequestMethod: Int {
    case send, createThread, setLanguage, setTheme, getThreads, openThread, validate
    var name: String {
        String(describing: self)
    }
}

// 1xxx are general errors. 3xxx are iOS specific.
public struct MMChatErrorCodes {
    static let noPushRegistrationId = -1001
    static let noWidget = -1002
    static let apiRequestFailure = -1003
    static let configSync = -1004
    static let noInternet = -1005
    static let attachmentNotAllowed = -1006
    static let wrongPayload = -1007
    static let messageLengthExceeded = -3001
    static let attachmentSizeExceeded = -3002
    static let jsOriginated = -3003 // Further error descriptions: https://www.infobip.com/docs/essentials/api-essentials/response-status-and-error-codes#live-chat-error-codes
    static let unknown = -3999
}

private typealias ec = MMChatErrorCodes

internal enum MMChatLocalError: Error, MMChatThrowable {
    case noPushRegistrationId,
         noWidget,
         messageLengthExceeded(UInt),
         attachmentSizeExceeded(UInt),
         attachmentNotAllowed,
         wrongPayload,
         apiRequestFailure(MMChatAPIRequestMethod, String?, String?)

    fileprivate var errorCode: Int {
        switch self {
        case .noPushRegistrationId:
            return ec.noPushRegistrationId
        case .noWidget:
            return ec.noWidget
        case .attachmentNotAllowed:
            return ec.attachmentNotAllowed
        case .wrongPayload:
            return ec.wrongPayload
        case .apiRequestFailure(_, _, _):
            return ec.apiRequestFailure
        case .messageLengthExceeded:
            return ec.messageLengthExceeded
        case .attachmentSizeExceeded:
            return ec.attachmentSizeExceeded
        }
    }

    var userInfo: [String: String] {
        var errorDescription: String = ""
        let prefix = "MMChatLocalError:"
        switch self {
        case .messageLengthExceeded(let limit):
            errorDescription = "\(prefix) Message length exceeded: \(limit) characters"
        case .attachmentSizeExceeded(let limit):
            errorDescription = "\(prefix) Attachment size exceeded: \(limit) bytes"
        case .wrongPayload:
            errorDescription = "\(prefix) Incorrect payload values"
        case .attachmentNotAllowed:
            errorDescription = "\(prefix) Attachment uploading or file extension not allowed"
        case .noPushRegistrationId:
            errorDescription = "\(prefix) No push registration Id. SDK cannot connect to the server."
        case .noWidget:
            errorDescription = "\(prefix) No widget. Chat cannot connect to the server"
        case .apiRequestFailure(let method, let reason, let payload):
            var info: [String: String] = [:]
            errorDescription = "\(prefix) - \(method.name) failed: \(reason ?? ""). Payload: \(payload ?? "")"
            info = [NSLocalizedDescriptionKey: errorDescription]
            if let reason = reason {
                info["reason"] = reason
            }
            if let payload = payload {
                info["payload"] = payload
            }
            return info
        }

        return [NSLocalizedDescriptionKey: errorDescription]
    }
    
    var technicalMessage: String {
        let prefix = "MMChatLocalError:"
        let waitingForChatAvailability = "We suggest to only show the chat after you have received confirmation the chat is ready to be presented, as explained here: https://github.com/infobip/mobile-messaging-sdk-ios/wiki/In%E2%80%90app-chat#library-events"

        switch self {
        case .wrongPayload:
            return "\(prefix) The message payload provided was wrong, please check the specifications here: https://github.com/infobip/mobile-messaging-sdk-ios/wiki/In%E2%80%90app-chat#livechat-widget-api"
        case .noPushRegistrationId:
            return "\(prefix) mandatory parameter push registration Id is null or blank. Its value is received only if your app has the correct setup. Please check that your application Code, p12 certificate, and environment (sandbox or production) are correct, as per documentation: https://github.com/infobip/mobile-messaging-sdk-ios/blob/master/README.md. \(waitingForChatAvailability)"
        case .noWidget:
            return "\(prefix) mandatory parameter 'widget' is null or blank. Its value is received only if your livechat setup is correct (ie, your widget exists and it is linked to a mobile app that matches your environment). Please follow the documentation: https://github.com/infobip/mobile-messaging-sdk-ios/wiki/In%E2%80%90app-chat#prerequisites. \(waitingForChatAvailability)"
        default:
            return userInfo.values.first ?? localizedDescription
        }
    }

    var foundationError: NSError {
        return NSError(chatError: self)
    }
    
    var localizedDescription: String {
        let somethingWrong = MMLocalization.localizedString(
            forKey: "mm_something_went_wrong",
            defaultString: "Something went wrong.")
        return String(format: "%1$@ (%2$@)", somethingWrong, "\(errorCode)")
    }
    
    var exception: MMChatException {
        return MMChatException(
            code: errorCode,
            name: "MMChatLocalError \(String(describing: self))",
            message: userInfo.values.first ?? localizedDescription)
    }
}

extension NSError {
    internal convenience init(chatError: MMChatLocalError, chatPayload: MMLivechatPayload? = nil) {
        self.init(
            domain: MMChatLocalErrorDomain,
            code: chatError.errorCode,
            userInfo: chatError.userInfo +  ["payload": chatPayload?.interfaceValue ?? ""])
    }
}

/*
 Chat Errors can be:
 - Local (ie input or setup related) in the form of a MMChatLocalError.
 - External (ie backend or widget related) from different sources (system, javascript exception, etc) as MMChatRemoteError.
 - Both are being propagated either as NSError or public MMChatException.
 */
struct MMChatRemoteError: OptionSet, MMChatThrowable {
    let rawValue: Int
    init(rawValue: Int = 0) { self.rawValue = rawValue }
    static let none = MMChatRemoteError([])
    static let jsError = MMChatRemoteError(rawValue: 1 << 0)
    static let configurationSyncError = MMChatRemoteError(rawValue: 1 << 1)
    static let noInternetConnectionError = MMChatRemoteError(rawValue: 1 << 2)
    var rawDescription: String?
    var additionalInfo: String?
    
    var localizedDescription: String {
        let somethingWrong = MMLocalization.localizedString(forKey: "mm_something_went_wrong",
                                                            defaultString: "Something went wrong.")
        if self.contains(.noInternetConnectionError) {
            return MMLocalization.localizedString(forKey: "mm_no_internet_connection",
                                                               defaultString: "No Internet connection")
        } else if self.contains(.configurationSyncError) || self.contains(.jsError) {
            guard let remoteDescription = rawDescription else { return somethingWrong }
            guard let additionalInfo = additionalInfo else {
                return String(format: "%1$@ - %2$@", somethingWrong, remoteDescription)
            }
            return String(format: "%1$@ - %2$@ %3$@", somethingWrong, remoteDescription, additionalInfo)
        }
        return somethingWrong
    }
    
    var exception: MMChatException {
        guard let json = rawDescription,
            let exception = try? JSONDecoder().decode(MMChatException.self, from: Data(json.utf8)) else {
            var code = ec.unknown
            switch  rawValue {
            case 1 << 0: code = ec.jsOriginated
            case 1 << 1: code = ec.configSync
            case 1 << 2: code = ec.noInternet
            default: break
            }
            return MMChatException(
                code: code,
                name: additionalInfo,
                message: rawDescription)
        }
        exception.name = additionalInfo
        return exception
    }
}

@objc
public enum MMChatExceptionDisplayMode: Int {
    case displayDefaultAlert,
         noDisplay
}

@objc
public class MMChatException: NSObject, Decodable, Error {
    public var code: Int
    public var name: String?
    public var message: String?
    public var origin = "iOS SDK"
    public var platform = "iOS"

    init(code: Int, name: String?, message: String?) {
        self.code = code
        self.name = name
        self.message = message
    }
}
