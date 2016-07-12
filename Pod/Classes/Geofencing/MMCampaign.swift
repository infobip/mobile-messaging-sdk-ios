//
//  MMCampaign.swift
//
//  Created by Ivan Cigic on 06/07/16.
//
//

import Foundation

public enum CampaignSource: String {
    case Local
    case Remote
}

public struct MMCampaign: Hashable, Equatable {
    public let id: String
    public var title: String
    public var message: String
    public var dateReceived: NSDate
    public var regions: Set<MMRegion> = []
    public var source = CampaignSource.Local
    
    public init(id: String, title: String, message: String, dateReceived: NSDate = NSDate(), regions: Set<MMRegion> = []) {
        self.id = id.isEmpty ? NSUUID().UUIDString : id
        self.title = title
        self.message = message
        self.dateReceived = dateReceived
        self.regions = regions
    }
    
    public var hashValue: Int {
        return id.hashValue
    }
}

public func ==(lhs: MMCampaign, rhs: MMCampaign) -> Bool {
    return lhs.id == rhs.id
}

