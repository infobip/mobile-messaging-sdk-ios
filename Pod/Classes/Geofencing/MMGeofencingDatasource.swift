//
//  MMGeofencingDatasource.swift
//
//  Created by Ivan Cigic on 06/07/16.
//
//

import Foundation
import CoreLocation

//FIXME: thread safety
class MMGeofencingDatasource {
	
	static let plistDir = "com.mobile-messaging.geo-data"
	static let plistFile = "CampaignsData.plist"
	var campaigns = Set<MMCampaign>() {
		didSet {
			for campaign in campaigns {
				addRegionsFromCampaign(campaign)
			}
		}
	}
	typealias RegionIdentifier = String
	var regions = [RegionIdentifier: MMRegion]()
	var notExpiredRegions: [MMRegion] {
		return regions.values.filter { $0.isExpired == false }
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
	
	func addRegionsFromCampaign(campaign: MMCampaign) {
		for region in campaign.regions {
			regions[region.identifier] = region
		}
	}
	
	func removeRegionsFromCampaign(campaign: MMCampaign) {
		for region in campaign.regions {
			regions[region.identifier] = nil
		}
	}
	
	func addNewCampaign(newCampaign: MMCampaign) {
		campaigns.insert(newCampaign)
		addRegionsFromCampaign(newCampaign)
		save()
	}
	
	func removeCampaign(campaingToRemove: MMCampaign) {
		campaigns.remove(campaingToRemove)
		removeRegionsFromCampaign(campaingToRemove)
		save()
	}
	
	lazy var rootURL: NSURL = {
		return NSFileManager.defaultManager().URLsForDirectory(NSSearchPathDirectory.ApplicationSupportDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask)[0]
	}()
	
	lazy var fileDirectoryURL: NSURL = {
		return self.rootURL.URLByAppendingPathComponent(MMGeofencingDatasource.plistDir)
	}()
	
	lazy var plistURL: NSURL = {
		self.fileDirectoryURL.URLByAppendingPathComponent(MMGeofencingDatasource.plistFile)
	}()
	
	func save() {
		//FIXME: move to BG thread
		if let path = fileDirectoryURL.path where !NSFileManager.defaultManager().fileExistsAtPath(path) {
			do {
				try NSFileManager.defaultManager().createDirectoryAtURL(fileDirectoryURL, withIntermediateDirectories: true, attributes: nil)
			} catch {
				MMLogError("Can't create a directory for a plist.")
				return
			}
		}
		
		
		let campaignDicts = campaigns.map { $0.dictionaryRepresentation }
		
		do {
			let data = try NSPropertyListSerialization.dataWithPropertyList(campaignDicts, format: NSPropertyListFormat.XMLFormat_v1_0, options: 0)
			try data.writeToURL(plistURL, options: NSDataWritingOptions.AtomicWrite)
		} catch {
			MMLogError("Can't write to a plist.")
		}
	}
	
	func load() {
		//FIXME: move to BG thread
		guard let plistPath = plistURL.path,
			let data = NSFileManager.defaultManager().contentsAtPath(plistPath),
			let plistArray = try? NSPropertyListSerialization.propertyListWithData(data, options: NSPropertyListMutabilityOptions.MutableContainersAndLeaves, format: nil),
			let plistDicts = plistArray as? [[String: AnyObject]] else
		{
			MMLogError("Can't load campaigns from plist.")
			self.campaigns = []
			return
		}
		
		campaigns = Set(plistDicts.flatMap(MMCampaign.init))
	}
}

