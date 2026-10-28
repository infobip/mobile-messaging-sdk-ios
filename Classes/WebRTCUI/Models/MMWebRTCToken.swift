// 
//  MMWebRTCToken.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
#if WEBRTCUI_ENABLED

struct MMWebRTCTokenRequestContext {
    let applicationCode: String
    let pushRegistrationId: String
    let identity: String
    let remoteApiProvider: RemoteAPIProvider

    init?(mmContext: MobileMessaging?, identity: String?) {
        guard let mmContext,
              let pushRegistrationId = mmContext.currentInstallation().pushRegistrationId,
              let identity,
              let remoteApiProvider = mmContext.remoteApiProvider else { return nil }
        self.applicationCode = mmContext.applicationCode
        self.pushRegistrationId = pushRegistrationId
        self.identity = identity
        self.remoteApiProvider = remoteApiProvider
    }
}

public final class MMWebRTCToken: NSObject, NSCoding, JSONDecodable, DictionaryRepresentable {
    public let token: String
    public let expirationTime: Date?
    
    required public init?(dictRepresentation dict: DictionaryRepresentation) {
        fatalError("init(dictRepresentation:) has not been implemented")
    }

    public var dictionaryRepresentation: DictionaryRepresentation {
        return ["token": token]
    }

    public override var hash: Int {
        return token.hashValue
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? MMWebRTCToken else {
            return false
        }
        return self.token == object.token
    }

    convenience public init?(json: JSON) {
        guard let code = json["token"].string else {
            return nil
        }
        self.init(token: code)
    }

    public init(token: String) {
        self.token = token
        self.expirationTime = nil
    }

    required public init?(coder aDecoder: NSCoder) {
        token = aDecoder.decodeObject(forKey: "token") as! String
        expirationTime = aDecoder.decodeObject(forKey: "expirationTime") as? Date
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(token, forKey: "token")
    }
    
    static func obtain(queue: DispatchQueue,
                       context: MMWebRTCTokenRequestContext?,
                       completion: @escaping (MMResult<MMWebRTCToken>) -> Void) {
        guard let context else {
            MMLogError("WebRTCUI unable to obtain token: missing installation or call identity")
            completion(.Failure(nil))
            return
        }
        let body: [String: Any] = ["identity": context.identity]
        let request = MMWebRTCTokenRequest(
            applicationCode: context.applicationCode,
            pushRegistrationId: context.pushRegistrationId,
            body: body)
        queue.async {
            context.remoteApiProvider.performRequest(
                request: request, 
                queue: queue,
                completion: completion)
        }
    }
}

class MMWebRTCTokenRequest: RequestData {
    init(applicationCode: String, pushRegistrationId: String?, body: RequestBody, baseURLString: String? = nil) {
        var baseURL: URL?
        if let baseURLString = baseURLString {
            baseURL = URL(string: baseURLString)
        }
        super.init(
            applicationCode: applicationCode,
            method: .post,
            path: .WebRTCToken,
            pushRegistrationId: pushRegistrationId,
            body: body,
            baseUrl: baseURL,
            accessToken: nil)
    }
}
#endif
