//
//  MMInboxFilterOptions.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 25.02.2022.
//

import Foundation


/**
 The class encapsulates filtering options for fetching Inbox messages from server.
 Always consider narrowing down the scope of messages that need to be fetched as it affects users traffic and networking performance.
 */
@objcMembers public class MMInboxFilterOptions: NSObject {
    public let fromDateTime: Date?
    public let toDateTime: Date?
    public let topic: String?
    public let limit: Int?
    
    /**
     - parameter fromDateTime: defines that messages with send datetime greater than or equal `fromDateTime` should be fetched. Default is undefined.
     - parameter toDateTime: defines that messages with send datetime less than `toDateTime` should be fetched. Default is undefined.
     - parameter topic: defines filter by topic name. Default is undefined.
     - parameter limit: defines maximum number of messages fetched within single request. Default is 20.
     */
    public init(fromDateTime: Date?, toDateTime: Date?, topic: String?, limit: Int?) {
        self.fromDateTime = fromDateTime
        self.toDateTime = toDateTime
        self.topic = topic
        self.limit = limit
    }
}
