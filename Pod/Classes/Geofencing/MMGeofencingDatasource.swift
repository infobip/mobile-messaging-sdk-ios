//
//  MMGeofencingDatasource.swift
//
//  Created by Ivan Cigic on 06/07/16.
//
//

import Foundation
import CoreLocation
import CoreData

//TODO: thread safety (it is safe till the only user is MMGeofencingService)
class MMGeofencingDatasource {
	
	static let plistDir = "com.mobile-messaging.geo-data"
	static let plistFile = "CampaignsData.plist"
	static let locationArchive = "currentLocation"
	
	let storage: MMCoreDataStorage
	let context: NSManagedObjectContext
	
	var messages = Set<MMGeoMessage>() {
		didSet {
			for message in messages {
				addRegions(fromMessage: message)
			}
		}
	}
	typealias RegionIdentifier = String
	var regionsDictionary = [RegionIdentifier: MMRegion]()
	var liveRegions: [MMRegion] {
		return regionsDictionary.values.filter { $0.isLive }
	}
	
	init(storage: MMCoreDataStorage) {
		self.storage = storage
		self.context = storage.newPrivateContext()
		loadCampainsFromPlist()
		loadLocationFromPlist()
		loadMessages()
	}
	
	func regions(withIdentifier regionIdentifier: String) -> [MMRegion]? {
		return messages.flatMap { $0.regions.filter({ (region) -> Bool in
			region.identifier == regionIdentifier
		}).first}
	}
	
	func message(withId id: String) -> MMGeoMessage? {
		return messages.filter({ $0.messageId == id }).first
	}
	
	func addRegions(fromMessage message: MMGeoMessage) {
		for region in message.regions {
			regionsDictionary[region.identifier] = region
		}
	}
	
	func removeRegions(withMessageId messageId: String) {
		messages.filter({
			return $0.messageId == messageId
		}).forEach {
			for region in $0.regions {
				regionsDictionary[region.identifier] = nil
			}
		}
	}
	
	func add(message message: MMGeoMessage) {
		messages.insert(message)
		addRegions(fromMessage: message)
	}
	
	func addRegions(regions: Set<MMRegion>) {
		for region in regions {
			regionsDictionary[region.identifier] = region
		}
	}

	func removeMessage(withId messageId: String) {
		removeRegions(withMessageId: messageId)
		messages.filter({
			return $0.messageId == messageId
		}).forEach {
			messages.remove($0)
		}
	}
	
	func loadMessages() {
		context.performBlockAndWait {
			let msgs = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageTypeValue == %i", MMMessageType.Geo.rawValue), inContext: self.context) as? [MessageManagedObject]
			
			if let messages = msgs?.flatMap(MMGeoMessage.init) {
				self.messages = Set(messages)
			}
		}
	}
	
	func triggerEvent(for eventType: MMRegionEventType, region: MMRegion) {
		guard let message = region.message else {
			return
		}
		region.triggerEvent(for: eventType)
		context.performBlockAndWait {
			if let msg = MessageManagedObject.MM_findFirstInContext(NSPredicate(format: "messageId == %@", message.messageId), context: self.context),
				var payload = msg.payload,
				var internalData = payload[MMAPIKeys.kInternalData] as? [String: AnyObject] {
				internalData += [MMAPIKeys.kGeo: message.regions.flatMap{$0.dictionaryRepresentation}]
				payload.updateValue(internalData, forKey: MMAPIKeys.kInternalData)
				msg.payload = payload
				self.context.MM_saveToPersistentStoreAndWait()
			}
		}
	}
	
	//MARK: for compatibility with previous storage
	private lazy var rootURL: NSURL = {
		return NSFileManager.defaultManager().URLsForDirectory(NSSearchPathDirectory.ApplicationSupportDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask)[0]
	}()
	
	private lazy var geoDirectoryURL: NSURL = {
		return self.rootURL.URLByAppendingPathComponent(MMGeofencingDatasource.plistDir)
	}()
	
	private lazy var plistURL: NSURL = {
		self.geoDirectoryURL.URLByAppendingPathComponent(MMGeofencingDatasource.plistFile)
	}()
	
	private var locationArchiveURL: NSURL {
		return self.geoDirectoryURL.URLByAppendingPathComponent(MMGeofencingDatasource.locationArchive)
	}
	
	private func loadCampainsFromPlist() {
		//FIXME: move to BG thread
		var campaigns: Set<MMPlistCampaign>
		guard let plistPath = plistURL.path,
			let data = NSFileManager.defaultManager().contentsAtPath(plistPath),
			let plistArray = try? NSPropertyListSerialization.propertyListWithData(data, options: NSPropertyListMutabilityOptions.MutableContainersAndLeaves, format: nil),
			let plistDicts = plistArray as? [[String: AnyObject]] else
		{
			MMLogError("Can't load campaigns from plist.")
			campaigns = []
			return
		}
		campaigns = Set(plistDicts.flatMap(MMPlistCampaign.init))
		context.performBlockAndWait {
		    campaigns.forEach({ (campaign) in
				let newDBMessage = MessageManagedObject.MM_createEntityInContext(context: self.context)
				newDBMessage.creationDate = campaign.dateReceived
				newDBMessage.messageId = "oldCampaign_\(campaign.id)"
				newDBMessage.isSilent = true
				newDBMessage.reportSent = true
				newDBMessage.seenDate = campaign.dateReceived
				newDBMessage.seenStatus = MMSeenStatus.SeenSent
				newDBMessage.messageType = .Geo
				newDBMessage.payload = [
					MMAPIKeys.kInternalData:
					[
						MMAPIKeys.kSilent:
						[
							MMAPIKeys.kTitle: campaign.title ?? NSNull(),
							MMAPIKeys.kBody: campaign.body ?? NSNull()
						],
						MMAPIKeys.kGeo: campaign.regions.flatMap{$0.dictionaryRepresentation}
					]
				]
			})
			
			self.context.MM_saveToPersistentStoreAndWait()
		}
		
		do {
			try NSFileManager.defaultManager().removeItemAtPath(plistPath)
		} catch {
			MMLogDebug("Can't remove old geo paths.")
			return
		}
	}
	
	private func loadLocationFromPlist() {
		guard let locationArchivePath = locationArchiveURL.path,
			let location = NSKeyedUnarchiver.unarchiveObjectWithFile(locationArchivePath) as? CLLocation else {
			return
		}
		
		MobileMessaging.currentInstallation?.location = location
		
		do {
			try NSFileManager.defaultManager().removeItemAtPath(locationArchivePath)
		} catch {
			MMLogDebug("Can't remove old geo paths.")
			return
		}
	}
}

