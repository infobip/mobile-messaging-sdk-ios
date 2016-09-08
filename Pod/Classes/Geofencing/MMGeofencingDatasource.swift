//
//  MMGeofencingDatasource.swift
//
//  Created by Ivan Cigic on 06/07/16.
//
//

import Foundation
import CoreLocation

//TODO: thread safety (it is safe till the only user is MMGeofencingService)
class MMGeofencingDatasource {
	
	static let plistDir = "com.mobile-messaging.geo-data"
	static let plistFile = "CampaignsData.plist"
	static let locationArchive = "currentLocation"
	var campaigns = Set<MMCampaign>() {
		didSet {
			for campaign in campaigns {
				addRegions(fromCampaign: campaign)
			}
		}
	}
	typealias RegionIdentifier = String
	var regionsDictionary = [RegionIdentifier: MMRegion]()
	var liveRegions: [MMRegion] {
		return regionsDictionary.values.filter { $0.isLive }
	}
	
	init() {
		loadFromDisk()
	}
	
	func campaing(withId id: String) -> MMCampaign? {
		return campaigns.filter({ $0.id == id }).first
	}
	
	func addRegions(fromCampaign campaign: MMCampaign) {
		for region in campaign.regions {
			regionsDictionary[region.identifier] = region
		}
	}
	
	func removeRegions(withCampaignId campaignId: String) {
		campaigns.filter({
			return $0.id == campaignId
		}).forEach {
			for region in $0.regions {
				regionsDictionary[region.identifier] = nil
			}
		}
	}
	
	func add(campaign campaign: MMCampaign) {
		campaigns.insert(campaign)
		addRegions(fromCampaign: campaign)
		saveToDisk()
	}
	
	func removeCampaign(withId campaignId: String) {
		removeRegions(withCampaignId: campaignId)
		campaigns.filter({
			return $0.id == campaignId
		}).forEach {
			campaigns.remove($0)
		}
		saveToDisk()
	}
	
	lazy var rootURL: NSURL = {
		return NSFileManager.defaultManager().URLsForDirectory(NSSearchPathDirectory.ApplicationSupportDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask)[0]
	}()
	
	lazy var geoDirectoryURL: NSURL = {
		return self.rootURL.URLByAppendingPathComponent(MMGeofencingDatasource.plistDir)
	}()
	
	lazy var plistURL: NSURL = {
		self.geoDirectoryURL.URLByAppendingPathComponent(MMGeofencingDatasource.plistFile)
	}()
	
	lazy var locationArchivePath: String = {
		let url = self.geoDirectoryURL.URLByAppendingPathComponent(MMGeofencingDatasource.locationArchive)
		return url.path!
	}()
	
	func saveToDisk() {
		//FIXME: move to BG thread
		if let path = geoDirectoryURL.path where !NSFileManager.defaultManager().fileExistsAtPath(path) {
			do {
				try NSFileManager.defaultManager().createDirectoryAtURL(geoDirectoryURL, withIntermediateDirectories: true, attributes: nil)
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
	
	func loadFromDisk() {
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

