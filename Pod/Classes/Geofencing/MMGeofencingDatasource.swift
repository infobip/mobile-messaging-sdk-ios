//
//  MMGeofencingDatasource.swift
//
//  Created by Ivan Cigic on 06/07/16.
//
//

import Foundation
import CoreLocation

public enum GeoDatasourceCampaignKeys: String {
    case Id = "Id"
    case Title = "Title"
    case Message = "Message"
    case DateReceived = "DateReceived"
    case Source = "Source"
    case Regions = "Regions"
    case RegionLatitude = "Latitude"
    case RegionLongitude = "Longitude"
    case RegionRadius = "Radius"
}

class MMGeofencingDatasource {
    static let plistFile = "CampaignsData.plist"
    static let sharedInstance = MMGeofencingDatasource()
    var campaigns: Set<MMCampaign> = []
    var regions: Set<MMRegion> {
        var regions: Set<MMRegion> = []
        
        // Create one set from all campaigns
        for campaign in self.campaigns {
            regions.unionInPlace(campaign.regions)
        }
        return regions
    }
    var numberOfCampaigns: Int {
        return campaigns.count
    }
    
    init() {
        load()
    }
    
    func campaingWithId(id: String) -> MMCampaign? {
        return campaigns.filter({ $0.id == id }).first
    }
    
    func addNewCampaign(newCampaign: MMCampaign) {
        if campaigns.contains(newCampaign) {
            campaigns.remove(newCampaign)
        }
        campaigns.insert(newCampaign)
        save()
    }
    
    func removeCampaign(campaingToRemove: MMCampaign) {
        campaigns.remove(campaingToRemove)
        save()
    }
    
    func save() {
        let rootUrl = NSFileManager.defaultManager().URLsForDirectory(NSSearchPathDirectory.ApplicationSupportDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask)[0]
        
        let fileDirectoryUrl = rootUrl.URLByAppendingPathComponent("com.mobile-messaging.geo-data")
        if let path = fileDirectoryUrl.path where !NSFileManager.defaultManager().fileExistsAtPath(path) {
            do {
                try NSFileManager.defaultManager().createDirectoryAtURL(fileDirectoryUrl,
                                                                        withIntermediateDirectories: true,
                                                                        attributes: nil)
            } catch { }
        }
        
        let plistUrl = fileDirectoryUrl.URLByAppendingPathComponent(MMGeofencingDatasource.plistFile)
        
        // Create NSMutableArray for storing to plist.
        var plistCampaignArray:[[String:AnyObject]] = []
        
        for cam in self.campaigns {
            var campaignDictionary : [String:AnyObject] = Dictionary()
            campaignDictionary[GeoDatasourceCampaignKeys.Id.rawValue] = cam.id
            campaignDictionary[GeoDatasourceCampaignKeys.Title.rawValue] = cam.title
            campaignDictionary[GeoDatasourceCampaignKeys.Message.rawValue] = cam.message
            campaignDictionary[GeoDatasourceCampaignKeys.DateReceived.rawValue] = cam.dateReceived
            campaignDictionary[GeoDatasourceCampaignKeys.Source.rawValue] = cam.source.rawValue
            
            var plistRegionArray:[[String:AnyObject]] = []
            for reg in cam.regions {
                var regionDictionary : [String:AnyObject] = Dictionary()
                regionDictionary[GeoDatasourceCampaignKeys.RegionLatitude.rawValue] = reg.center.latitude
                regionDictionary[GeoDatasourceCampaignKeys.RegionLongitude.rawValue] = reg.center.longitude
                regionDictionary[GeoDatasourceCampaignKeys.RegionRadius.rawValue] = reg.radius
                plistRegionArray.append(regionDictionary)
            }
            campaignDictionary[GeoDatasourceCampaignKeys.Regions.rawValue] = plistRegionArray
            plistCampaignArray.append(campaignDictionary)
        }
        
        do {
            let data = try NSPropertyListSerialization.dataWithPropertyList(plistCampaignArray, format: NSPropertyListFormat.XMLFormat_v1_0, options: 0)
            try data.writeToURL(plistUrl, options: NSDataWritingOptions.AtomicWrite)
        } catch {
            // Log message
        }
    }
    
    func load() {
        
        let rootUrl = NSFileManager.defaultManager().URLsForDirectory(NSSearchPathDirectory.ApplicationSupportDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask)[0]
        
        let fileDirectoryUrl = rootUrl.URLByAppendingPathComponent("com.mobile-messaging.geo-data")
        let plistUrl = fileDirectoryUrl.URLByAppendingPathComponent(MMGeofencingDatasource.plistFile)
        let plistPath = plistUrl.path
        
        if let path = plistPath {
            if !NSFileManager.defaultManager().fileExistsAtPath(path) {
                self.campaigns = []
                return
            }
        }
        
        let plistData = NSFileManager.defaultManager().contentsAtPath(plistPath!)
        var plistArray: [[String:AnyObject]] = []
        do {
            if let data = plistData {
                plistArray =
                    try NSPropertyListSerialization.propertyListWithData(
                        data,
                        options: NSPropertyListMutabilityOptions.MutableContainersAndLeaves,
                        format: nil) as! [[String: AnyObject]]
            }
            
        } catch {
            MMLogInfo("Can't load data.")
        }
        
        var newCampaigns: Set<MMCampaign> = []
        for dict in plistArray {
            let id = dict[GeoDatasourceCampaignKeys.Id.rawValue] as! String
            let title = dict[GeoDatasourceCampaignKeys.Title.rawValue] as! String
            let message = dict[GeoDatasourceCampaignKeys.Message.rawValue] as! String
            let source = dict[GeoDatasourceCampaignKeys.Source.rawValue] as! String
            let dateReceived = dict[GeoDatasourceCampaignKeys.DateReceived.rawValue] as? NSDate ?? NSDate()
            let regionArray = dict[GeoDatasourceCampaignKeys.Regions.rawValue] as! [[String:AnyObject]]
            
            var newCampaign = MMCampaign(id: id,
                                         title: title,
                                         message: message,
                                         dateReceived: dateReceived)
            newCampaign.source = CampaignSource(rawValue: source)!
            
            var regions: Set<MMRegion> = []
            for regionDict in regionArray {
                let latitude = regionDict[GeoDatasourceCampaignKeys.RegionLatitude.rawValue] as! Double
                let longitude = regionDict[GeoDatasourceCampaignKeys.RegionLongitude.rawValue] as! Double
                let radius = regionDict[GeoDatasourceCampaignKeys.RegionRadius.rawValue] as! Double
                let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                let newRegion = MMRegion(center: center, radius: radius, campaign: newCampaign)
                regions.insert(newRegion)
            }
            newCampaign.regions = regions
            newCampaigns.insert(newCampaign)
        }
        self.campaigns = newCampaigns
    }
}

