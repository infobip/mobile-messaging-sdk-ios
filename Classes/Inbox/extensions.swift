// 
//  extensions.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

extension RemoteAPIProvider {
    func getInbox(applicationCode: String, accessToken: String?, externalUserId: String, from: Date?, to: Date?, limit: Int?, topic: String?, cursor: String?, queue: DispatchQueue, completion: @escaping (FetchInboxResult) -> Void) {
        let request = GetInbox(applicationCode: applicationCode, accessToken: accessToken, externalUserId: externalUserId, from: from, to: to, limit: limit, topic: topic, cursor: cursor)
        performRequest(request: request, queue: queue, completion: completion)
    }
    
    func deleteInboxMessages(applicationCode: String, accessToken: String?, externalUserId: String, messageIds: [String], queue: DispatchQueue, completion: @escaping (DeleteInboxMessagesResult) -> Void) {
        let request = DeleteInboxMessages(applicationCode: applicationCode, accessToken: accessToken, externalUserId: externalUserId, messageIds: messageIds)
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
