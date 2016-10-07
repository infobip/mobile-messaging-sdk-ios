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
				addRegions(from: message)
			}
		}
	}
	typealias RegionIdentifier = String
	var regions = [RegionIdentifier: MMRegion]()
	var currentLocation: CLLocation?
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
		return messages.flatMap {
			$0.regions.filter( { region -> Bool in
				region.identifier == regionIdentifier
			}).first
		}
	}
	
	func message(withId id: String) -> MMGeoMessage? {
		return messages.filter({ $0.messageId == id }).first
	}
	
	func addRegions(from message: MMGeoMessage) {
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
	
	func add(message: MMGeoMessage) {
		messages.insert(message)
		addRegions(from: message)
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
		context.performAndWait {
			let msgs = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageTypeValue == %i", MMMessageType.Geo.rawValue), context: self.context)
			
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
		context.performAndWait {
			if let msg = MessageManagedObject.MM_findFirstWithPredicate(NSPredicate(format: "messageId == %@", message.messageId), context: self.context), var payload = msg.payload, var internalData = payload[MMAPIKeys.kInternalData] as? DictionaryRepresentation
			{
				internalData += [MMAPIKeys.kGeo: message.regions.map { $0.dictionaryRepresentation }]
				payload.updateValue(internalData, forKey: MMAPIKeys.kInternalData)
				msg.payload = payload
				self.context.MM_saveToPersistentStoreAndWait()
			}
		}
	}
	
	//MARK: for compatibility with previous storage
	private lazy var rootURL: URL = {
		return FileManager.default.urls(for: FileManager.SearchPathDirectory.applicationSupportDirectory, in: FileManager.SearchPathDomainMask.userDomainMask)[0]
	}()
	
	private lazy var geoDirectoryURL: URL = {
		return self.rootURL.appendingPathComponent(MMGeofencingDatasource.plistDir)
	}()
	
	private lazy var plistURL: URL = {
		return self.geoDirectoryURL.appendingPathComponent(MMGeofencingDatasource.plistFile)
	}()
	
	private var locationArchiveURL: URL {
		return self.geoDirectoryURL.appendingPathComponent(MMGeofencingDatasource.locationArchive)
	}
	
	private func loadCampainsFromPlist() {
		//FIXME: move to BG thread
		var campaigns: Set<MMPlistCampaign>
		let plistPath = plistURL.path
		guard let data = FileManager.default.contents(atPath: plistPath), let plistArray = try? PropertyListSerialization.propertyList(from: data, options: PropertyListSerialization.ReadOptions.mutableContainersAndLeaves, format: nil), let plistDicts = plistArray as? [DictionaryRepresentation] else
		{
			MMLogError("Can't load campaigns from plist.")
			campaigns = []
			return
		}
		campaigns = Set(plistDicts.flatMap(MMPlistCampaign.init))
		context.performAndWait {
		    campaigns.forEach({ (campaign) in
				let newDBMessage = MessageManagedObject.MM_createEntityInContext(context: self.context)
				newDBMessage.creationDate = campaign.dateReceived
				newDBMessage.messageId = "oldCampaign_\(campaign.id)"
				newDBMessage.isSilent = true
				newDBMessage.reportSent = true
				newDBMessage.seenDate = campaign.dateReceived
				newDBMessage.seenStatus = MMSeenStatus.SeenSent
				newDBMessage.messageType = .Geo
				
				let title: Any = campaign.title ?? NSNull()
				let body: Any = campaign.body ?? NSNull()
				
				newDBMessage.payload = [
					MMAPIKeys.kInternalData:
					[
						MMAPIKeys.kSilent:
						[
							MMAPIKeys.kTitle: title,
							MMAPIKeys.kBody: body
						],
						MMAPIKeys.kGeo: campaign.regions.map{$0.dictionaryRepresentation}
					]
				]
			})
			
			self.context.MM_saveToPersistentStoreAndWait()
		}
		
		do {
			try FileManager.default.removeItem(atPath: plistPath)
		} catch {
			MMLogDebug("Can't remove old geo paths.")
			return
		}
	}
	
	private func loadLocationFromPlist() {
		let locationArchivePath = locationArchiveURL.path
		guard let location = NSKeyedUnarchiver.unarchiveObject(withFile: locationArchivePath) as? CLLocation else
		{
			return
		}
		MobileMessaging.currentInstallation?.location = location
		
		do {
			try FileManager.default.removeItem(atPath: locationArchivePath)
		} catch {
			MMLogDebug("Can't remove old geo paths.")
			return
		}
	}
}

