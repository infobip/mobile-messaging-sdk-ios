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
	
	func campaingWithId(_ id: String) -> MMCampaign? {
		return campaigns.filter({ $0.id == id }).first
	}
	
	func addRegionsFromCampaign(_ campaign: MMCampaign) {
		for region in campaign.regions {
			regions[region.identifier] = region
		}
	}
	
	func removeRegionsFromCampaign(_ campaign: MMCampaign) {
		for region in campaign.regions {
			regions[region.identifier] = nil
		}
	}
	
	func addNewCampaign(_ newCampaign: MMCampaign) {
		campaigns.insert(newCampaign)
		addRegionsFromCampaign(newCampaign)
		save()
	}
	
	func removeCampaign(_ campaingToRemove: MMCampaign) {
		campaigns.remove(campaingToRemove)
		removeRegionsFromCampaign(campaingToRemove)
		save()
	}
	
	lazy var rootURL: URL = {
		return FileManager.default.urls(for: FileManager.SearchPathDirectory.applicationSupportDirectory, in: FileManager.SearchPathDomainMask.userDomainMask)[0]
	}()
	
	lazy var fileDirectoryURL: URL = {
		return self.rootURL.appendingPathComponent(MMGeofencingDatasource.plistDir)
	}()
	
	lazy var plistURL: URL = {
		return self.fileDirectoryURL.appendingPathComponent(MMGeofencingDatasource.plistFile)
	}()
	
	func save() {
		//FIXME: move to BG thread
		if !FileManager.default.fileExists(atPath: fileDirectoryURL.path) {
			do {
				try FileManager.default.createDirectory(at: fileDirectoryURL as URL, withIntermediateDirectories: true, attributes: nil)
			} catch {
				MMLogError("Can't create a directory for a plist.")
				return
			}
		}
		
		
		let campaignDicts = campaigns.map { $0.dictionaryRepresentation }
		
		do {
			let data = try PropertyListSerialization.data(fromPropertyList: campaignDicts, format: PropertyListSerialization.PropertyListFormat.xml, options: 0)
			try data.write(to: plistURL, options: NSData.WritingOptions.atomicWrite)
		} catch {
			MMLogError("Can't write to a plist.")
		}
	}
	
	func load() {
		//FIXME: move to BG thread
		guard let data = FileManager.default.contents(atPath: plistURL.path),
			let plistArray = try? PropertyListSerialization.propertyList(from: data, options: PropertyListSerialization.MutabilityOptions.mutableContainersAndLeaves, format: nil),
			let plistDicts = plistArray as? [[String: AnyObject]] else
		{
			MMLogError("Can't load campaigns from plist.")
			self.campaigns = []
			return
		}
		
		campaigns = Set(plistDicts.flatMap(MMCampaign.init))
	}
}

