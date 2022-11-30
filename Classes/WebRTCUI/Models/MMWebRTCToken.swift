//
//  MMWebRTCToken.swift
//  MobileMessaging
//
//  Created by Francisco Fortes on 13/10/2022.
//

import Foundation

public final class MMWebRTCToken: NSObject, NSCoding, JSONDecodable, DictionaryRepresentable {
    public let token: String
    public let expirationTime: Date?
    
    required init?(dictRepresentation dict: DictionaryRepresentation) {
        fatalError("init(dictRepresentation:) has not been implemented")
    }

    var dictionaryRepresentation: DictionaryRepresentation {
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

    convenience init?(json: JSON) {
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
    
    static func obtain(queue: DispatchQueue, completion: @escaping (MMResult<MMWebRTCToken>) -> Void) {
        guard let pushRegId = MobileMessaging.sharedInstance?.currentInstallation().pushRegistrationId,
        let appCode = MobileMessaging.sharedInstance?.applicationCode,
        let webrtcAppId = MMWebRTCService.sharedInstance?.applicationId else { return }
        let body: [String: Any] = ["identity": pushRegId,
                                   "applicationId": webrtcAppId]
        let request = MMWebRTCTokenRequest(
            applicationCode: appCode,
            pushRegistrationId: pushRegId,
            body: body)
        queue.async {
            MobileMessaging.sharedInstance?.remoteApiProvider.performRequest(request: request, queue: queue, completion: completion)
        }
    }
}

class MMWebRTCTokenRequest: RequestData {
    init(applicationCode: String, pushRegistrationId: String?, body: RequestBody) {
        super.init(applicationCode: applicationCode, method: .post, path: .WebRTCToken,
                   pushRegistrationId: pushRegistrationId, body: body,
                   baseUrl: URL(string: Consts.APIValues.prodDynamicBaseURLString))
    }
}
