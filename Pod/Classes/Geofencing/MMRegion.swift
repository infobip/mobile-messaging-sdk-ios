//
//  MMRegion.swift
//
//  Created by Ivan Cigic on 06/07/16.
//
//

import Foundation
import CoreLocation

public class MMRegion: Hashable, Equatable {
    public let id: String
    public var center: CLLocationCoordinate2D
    public var radius: Double
    public var campaign: MMCampaign?
    
    public init(center: CLLocationCoordinate2D, radius: Double, campaign: MMCampaign? = nil) {
        self.center = center
        self.radius = radius
        self.campaign = campaign
        self.id = "\(self.radius) \(self.center.longitude) \(self.center.latitude)"
    }
    
//    public var id: String {
//        get {
//            return "\(self.radius) \(self.center.longitude) \(self.center.latitude)"
//        }
//    }
    
    public var hashValue: Int {
        return id.hashValue
    }
}

public func ==(lhs: MMRegion, rhs: MMRegion) -> Bool {
    return lhs.id == rhs.id
}
