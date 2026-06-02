// 
//  MMRequests.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2026 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

public enum MMHTTPMethod: String {
    case options = "OPTIONS"
    case get     = "GET"
    case head    = "HEAD"
    case post    = "POST"
    case put     = "PUT"
    case patch   = "PATCH"
    case delete  = "DELETE"
    case trace   = "TRACE"
    case connect = "CONNECT"
}

public typealias MMHTTPHeaders = [String: String]

// MARK: - API Paths

public enum APIPath: String {
    case SeenMessages = "/mobile/2/messages/seen"
    case SyncMessages = "/mobile/5/messages"
    case MOMessage = "/mobile/1/messages/mo"
    case LibraryVersion = "/mobile/3/version"
    case BaseURL = "/mobile/1/baseurl"
    case DeliveryReport = "/mobile/1/messages/deliveryreport"

    case AppInstancePersonalize = "/mobile/1/appinstance/{pushRegistrationId}/personalize"
    case AppInstanceDepersonalize = "/mobile/1/appinstance/{pushRegistrationId}/depersonalize"
    case AppInstanceUser_CRUD = "/mobile/1/appinstance/{pushRegistrationId}/user"
    case AppInstance_xRUD = "/mobile/1/appinstance/{pushRegistrationId}"
    case AppInstance_Cxxx = "/mobile/1/appinstance"
    case UserSession = "/mobile/1/appinstance/{pushRegistrationId}/user/events/session"
    case CustomEvents = "/mobile/1/appinstance/{pushRegistrationId}/user/events/custom"

    case Inbox = "/mobile/1/user/{externalUserId}/inbox/apns/messages"

    case ChatWidget = "/mobile/1/chat/widget"
    case WebRTCToken = "/webrtc/1/token"
    case LiveChatInfo = "/mobile/1/appinstance/{pushRegistrationId}/user/livechatinfo"

    case empty = ""
}

class SeenStatusSendingRequest: PostRequest {
    typealias ResponseType = EmptyResponse

    init(applicationCode: String, pushRegistrationId: String?, body: RequestBody) {
        super.init(applicationCode: applicationCode, path: .SeenMessages, pushRegistrationId: pushRegistrationId, body: body)
    }
}

class LibraryVersionRequest: GetRequest {
    typealias ResponseType = LibraryVersionResponse

    init(applicationCode: String, pushRegistrationId: String?) {
        super.init(applicationCode: applicationCode, path: .LibraryVersion, pushRegistrationId: pushRegistrationId, parameters: [Consts.PushRegistration.platform: Consts.APIValues.platformType])
    }
}

class BaseUrlRequest: GetRequest {
    typealias ResponseType = BaseUrlResponse

    init(applicationCode: String) {
        super.init(applicationCode: applicationCode, path: .BaseURL, baseUrl: URL.init(string: Consts.APIValues.prodDynamicBaseURLString))
    }
}


class MessagesSyncRequest: PostRequest {
    typealias ResponseType = MessagesSyncResponse

    init(applicationCode: String, pushRegistrationId: String, body: RequestBody) {
        super.init(applicationCode: applicationCode, path: .SyncMessages, pushRegistrationId: pushRegistrationId, body: body, parameters: {
            var params = RequestParameters()
            params[Consts.PushRegistration.platform] = Consts.APIValues.platformType
            return params
        }())
    }
}

class DeliveryReportRequest: PostRequest {
    typealias ResponseType = EmptyResponse

    init(applicationCode: String, pushRegistrationId: String? = nil, body: RequestBody) {
        super.init(applicationCode: applicationCode, path: .DeliveryReport, pushRegistrationId: pushRegistrationId, body: body)
    }
}

class MOMessageSendingRequest: PostRequest {
    typealias ResponseType = MOMessageSendingResponse

    init(applicationCode: String, pushRegistrationId: String, body: RequestBody) {
        super.init(applicationCode: applicationCode, path: .MOMessage, pushRegistrationId: pushRegistrationId, body: body, parameters: [Consts.PushRegistration.platform : Consts.APIValues.platformType])
    }
}

class PostCustomEvent: PostRequest {
    typealias ResponseType = EmptyResponse

    init(applicationCode: String, pushRegistrationId: String, validate: Bool, requestBody: RequestBody?) {
        super.init(applicationCode: applicationCode, path: .CustomEvents, pushRegistrationId: pushRegistrationId, body: requestBody, parameters: ["validate": validate], pathParameters: ["{pushRegistrationId}": pushRegistrationId])
    }
}

class PostUserSession: PostRequest {
    typealias ResponseType = EmptyResponse

    init(applicationCode: String, pushRegistrationId: String, requestBody: RequestBody?) {
        super.init(applicationCode: applicationCode, path: .UserSession, pushRegistrationId: pushRegistrationId, body: requestBody, pathParameters: ["{pushRegistrationId}": pushRegistrationId])
    }
}

class GetInstance: GetRequest {
    typealias ResponseType = MMInstallation

    init(applicationCode: String, pushRegistrationId: String, returnPushServiceToken: Bool) {
        super.init(applicationCode: applicationCode, path: .AppInstance_xRUD, pushRegistrationId: pushRegistrationId, parameters: ["rt": returnPushServiceToken], pathParameters: ["{pushRegistrationId}": pushRegistrationId])
    }
}

class PatchInstance: PatchRequest {
    typealias ResponseType = EmptyResponse

    init?(applicationCode: String, authPushRegistrationId: String, refPushRegistrationId: String, body: RequestBody, returnPushServiceToken: Bool) {
        super.init(applicationCode: applicationCode, path: .AppInstance_xRUD, pushRegistrationId: authPushRegistrationId, body: body, parameters: ["rt": returnPushServiceToken], pathParameters: ["{pushRegistrationId}": refPushRegistrationId])
        if self.body?.isEmpty ?? true {
            return nil
        }
    }
}

class PostInstance: PostRequest {
    typealias ResponseType = MMInstallation

    init?(applicationCode: String, body: RequestBody, returnPushServiceToken: Bool) {
        super.init(applicationCode: applicationCode, path: .AppInstance_Cxxx, body: body, parameters: ["rt": returnPushServiceToken])
        if self.body?.isEmpty ?? true {
            return nil
        }
    }
}

class DeleteInstance: DeleteRequest {
    typealias ResponseType = EmptyResponse

    init(applicationCode: String, pushRegistrationId: String, expiredPushRegistrationId: String) {
        super.init(applicationCode: applicationCode, path: .AppInstance_xRUD, pushRegistrationId: pushRegistrationId, pathParameters: ["{pushRegistrationId}": expiredPushRegistrationId])
    }
}

class GetUser: GetRequest {
    typealias ResponseType = MMUser

    init(applicationCode: String, pushRegistrationId: String, returnInstance: Bool, returnPushServiceToken: Bool, accessToken: String? = nil) {
        super.init(applicationCode: applicationCode, path: .AppInstanceUser_CRUD, pushRegistrationId: pushRegistrationId, parameters: ["rt": returnPushServiceToken, "ri": returnInstance], pathParameters: ["{pushRegistrationId}": pushRegistrationId], accessToken: accessToken)
    }
}

class PatchUser: PatchRequest {
    typealias ResponseType = EmptyResponse

    init?(applicationCode: String, pushRegistrationId: String, body: RequestBody?, returnInstance: Bool, returnPushServiceToken: Bool, accessToken: String? = nil) {
        guard let body = body else {
            return nil
        }
        super.init(applicationCode: applicationCode, path: .AppInstanceUser_CRUD, pushRegistrationId: pushRegistrationId, body: body, parameters: ["rt": returnPushServiceToken, "ri": returnInstance], pathParameters: ["{pushRegistrationId}": pushRegistrationId], accessToken: accessToken)
        if self.body?.isEmpty ?? true {
            return nil
        }
    }
}

class PostDepersonalize: PostRequest {
    typealias ResponseType = EmptyResponse

    init(applicationCode: String, pushRegistrationId: String, pushRegistrationIdToDepersonalize: String) {
        super.init(applicationCode: applicationCode, path: .AppInstanceDepersonalize, pushRegistrationId: pushRegistrationId, pathParameters: ["{pushRegistrationId}": pushRegistrationIdToDepersonalize])
    }
}

class PostPersonalize: PostRequest {
    typealias ResponseType = MMUser

    init(applicationCode: String, pushRegistrationId: String, body: RequestBody, forceDepersonalize: Bool, keepAsLead: Bool, setDeviceAsPrimary: Bool, accessToken: String? = nil) {
        super.init(applicationCode: applicationCode, path: .AppInstancePersonalize, pushRegistrationId: pushRegistrationId, body: body, parameters: ["forceDepersonalize": forceDepersonalize, "keepAsLead": keepAsLead, "setDeviceAsPrimary": setDeviceAsPrimary], pathParameters: ["{pushRegistrationId}": pushRegistrationId], accessToken: accessToken)
    }
}

class WebInAppClickReportRequest: GetRequest {
    typealias ResponseType = EmptyResponse
    
    private let buttonIdx: String
    
    init(url: URL, applicationCode: String, pushRegistrationId: String, buttonIdx: String) {
        self.buttonIdx = buttonIdx
        super.init(
            applicationCode: applicationCode,
            path: .empty,
            pushRegistrationId: pushRegistrationId,
            baseUrl: url
        )
    }
    
    override var headers: MMHTTPHeaders? {
        var headers = super.headers ?? [:]
        headers[MMConsts.APIHeaders.buttonidx] = buttonIdx
        return headers
    }
}


//MARK: - Base

public typealias RequestBody = [String: Any]
public typealias RequestParameters = [String: Any]

open class RequestData {
    public init(applicationCode: String, method: MMHTTPMethod, path: APIPath, pushRegistrationId: String? = nil, body: RequestBody? = nil, parameters: RequestParameters? = nil, pathParameters: [String: String]? = nil, baseUrl: URL? = nil, accessToken: String? = nil) {
        self.applicationCode = applicationCode
        self.method = method
        self.path = path
        self.pushRegistrationId = pushRegistrationId
        self.body = body
        self.parameters = parameters
        self.pathParameters = pathParameters
        self.baseUrl = baseUrl
        self.accessToken = accessToken
    }
    let accessToken: String?
    let applicationCode: String
    public let pushRegistrationId: String?
    let method: MMHTTPMethod
    let path: APIPath
    let baseUrl: URL?

    var headers: MMHTTPHeaders? {
        var headers: MMHTTPHeaders = [:]
        if let accessToken = accessToken {
            headers[MMConsts.APIHeaders.authorization] = "\(MMConsts.APIHeaders.authorizationBearer) \(accessToken)"
        } else {
            headers[MMConsts.APIHeaders.authorization] = "\(MMConsts.APIHeaders.authorizationApiKey) \(self.applicationCode)"
        }
        headers[MMConsts.APIHeaders.applicationcode] = calculateAppCodeHash(self.applicationCode)
        headers[MMConsts.APIHeaders.userAgent] = MobileMessaging.userAgent.currentUserAgentString
        headers[MMConsts.APIHeaders.foreground] = String(MobileMessaging.application.isInForegroundState)
        headers[MMConsts.APIHeaders.pushRegistrationId] = self.pushRegistrationId
        headers[MMConsts.APIHeaders.sessionId] = MobileMessaging.sharedInstance?.userSessionService.currentSessionId
        headers[MMConsts.APIHeaders.accept] = "application/json"
        headers[MMConsts.APIHeaders.contentType] = "application/json"
        if let installationId = getInstallationId() {
            headers[MMConsts.APIHeaders.installationId] = installationId
        }
        return headers
    }
    let body: RequestBody?
    let parameters: RequestParameters?
    let pathParameters: [String: String]?

    var resolvedPath: String {
        var ret: String = path.rawValue
        pathParameters?.forEach { (pathParameterName, pathParameterValue) in
            ret = ret.replacingOccurrences(of: pathParameterName, with: pathParameterValue)
        }
        return ret
    }
    
    private func getInstallationId() -> String? {
        // normal SDK
        if let installationId = MobileMessaging.sharedInstance?.installationService?.getUniversalInstallationId() {
            return installationId
        } else if let appGroupId = Bundle.mainAppBundle.appGroupId,
                  let sharedDefaults = UserDefaults(suiteName: appGroupId) {
            // NSE fallback
            return sharedDefaults.string(forKey: Consts.UserDefaultsKeys.universalInstallationId)
        }
        return nil
    }
}

open class GetRequest: RequestData {
    public init(applicationCode: String, path: APIPath, pushRegistrationId: String? = nil, body: RequestBody? = nil, parameters: RequestParameters? = nil, pathParameters: [String: String]? = nil, baseUrl: URL? = nil, accessToken: String? = nil) {
        super.init(applicationCode: applicationCode, method: .get, path: path, pushRegistrationId: pushRegistrationId, body: body, parameters: parameters, pathParameters: pathParameters, baseUrl: baseUrl, accessToken: accessToken)
    }
}

open class PostRequest: RequestData {
    public init(applicationCode: String, path: APIPath, pushRegistrationId: String? = nil, body: RequestBody? = nil, parameters: RequestParameters? = nil, pathParameters: [String: String]? = nil, accessToken: String? = nil) {
        super.init(applicationCode: applicationCode, method: .post, path: path, pushRegistrationId: pushRegistrationId, body: body, parameters: parameters, pathParameters: pathParameters, accessToken: accessToken)
    }
}

class DeleteRequest: RequestData {
    init(applicationCode: String, path: APIPath, pushRegistrationId: String? = nil, body: RequestBody? = nil, parameters: RequestParameters? = nil, pathParameters: [String: String]? = nil) {
        super.init(applicationCode: applicationCode, method: .delete, path: path, pushRegistrationId: pushRegistrationId, body: body, parameters: parameters, pathParameters: pathParameters, accessToken: nil)
    }
}

class PutRequest: RequestData {
    init(applicationCode: String, path: APIPath, pushRegistrationId: String? = nil, body: RequestBody? = nil, parameters: RequestParameters? = nil, pathParameters: [String: String]? = nil) {
        super.init(applicationCode: applicationCode, method: .put, path: path, pushRegistrationId: pushRegistrationId, body: body, parameters: parameters, pathParameters: pathParameters, accessToken: nil)
    }
}

class PatchRequest: RequestData {
    init(applicationCode: String, path: APIPath, pushRegistrationId: String? = nil, body: RequestBody? = nil, parameters: RequestParameters? = nil, pathParameters: [String: String]? = nil, accessToken: String? = nil) {
        super.init(applicationCode: applicationCode, method: .patch, path: path, pushRegistrationId: pushRegistrationId, body: body, parameters: parameters, pathParameters: pathParameters, accessToken: accessToken)
    }
}

// MARK: - URLRequest building (replaces JSONRequestEncoding + SanitizedJSONSerialization)

extension RequestData {
    func buildURLRequest(baseURL: URL) throws -> URLRequest {
        let urlString = baseURL.absoluteString + resolvedPath
        guard var components = URLComponents(string: urlString) else {
            throw URLError(.badURL)
        }

        if let parameters = parameters, !parameters.isEmpty {
            components.queryItems = parameters.keys.sorted().flatMap { key in
                queryItems(fromKey: key, value: parameters[key]!)
            }
        }

        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        if let body = body {
            request.httpBody = try JSONSerialization.data(
                withJSONObject: body,
                options: [.withoutEscapingSlashes, .sortedKeys]
            )
        }

        return request
    }

    private func queryItems(fromKey key: String, value: Any) -> [URLQueryItem] {
        if let bool = value as? Bool {
            return [URLQueryItem(name: key, value: bool ? "1" : "0")]
        } else if let number = value as? NSNumber,
                  number === kCFBooleanTrue || number === kCFBooleanFalse {
            return [URLQueryItem(name: key, value: number.boolValue ? "1" : "0")]
        } else {
            return [URLQueryItem(name: key, value: "\(value)")]
        }
    }
}

public struct MMDownloadResult {
    public let value: Data?
    public let destinationURL: URL?
    public let error: Error?
    
    public init(value: Data?, destinationURL: URL?, error: Error?) {
        self.value = value
        self.destinationURL = destinationURL
        self.error = error
    }
}
