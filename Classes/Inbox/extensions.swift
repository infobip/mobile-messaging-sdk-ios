//
//  extensions.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 02.03.2022.
//

import Foundation

extension RemoteAPIProvider {
    func getInbox(applicationCode: String, accessToken: String?, externalUserId: String, from: Date?, to: Date?, limit: Int?, topic: String?, queue: DispatchQueue, completion: @escaping (FetchInboxResult) -> Void) {
        let request = GetInbox(applicationCode: applicationCode, accessToken: accessToken, externalUserId: externalUserId, from: from, to: to, limit: limit, topic: topic)
        performRequest(request: request, queue: queue, completion: completion)
    }
}

extension MobileMessaging {
    public class var inbox: MMInboxService? {
        if MMInboxService.sharedInstance == nil {
            guard let defaultContext = MobileMessaging.sharedInstance else {
                return nil
            }
            MMInboxService.sharedInstance = MMInboxService(mmContext: defaultContext)
        }
        return MMInboxService.sharedInstance
    }
}
