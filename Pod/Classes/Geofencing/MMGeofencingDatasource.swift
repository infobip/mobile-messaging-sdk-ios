//
//  MMGeofencingDatasource.swift
//
//  Created by Ivan Cigic on 06/07/16.
//
//

import Foundation
import CoreLocation
import CoreData

class GeofencingDatasource {
	
	let storage: MMCoreDataStorage
	let context: NSManagedObjectContext
	
	var messages = Set<MMGeoMessage>() {
		didSet {
			messages.forEach { addRegions(from: $0) }
		}
	}
	typealias RegionIdentifier = String
	var regions = [RegionIdentifier: MMRegion]()
	var currentLocation: CLLocation?
	var regionsDictionary = [RegionIdentifier: MMRegion]()
	var liveRegions: [MMRegion] {
		return regions(from: Set(messages.filter({ $0.isNotExpired })))
	}
	
	var allRegions: [MMRegion] {
		return regions(from: messages)
	}
	
	init(storage: MMCoreDataStorage) {
		self.storage = storage
		self.context = storage.newPrivateContext()
		self.reload()
	}
	
	func validRegionsForEntryEventNow(with regionIdentifier: RegionIdentifier) -> [MMRegion]? {
		return validRegionsNow(for: .entry, with: regionIdentifier)
	}
	
	func validRegionsForExitEventNow(with regionIdentifier: RegionIdentifier) -> [MMRegion]? {
		return validRegionsNow(for: .exit, with: regionIdentifier)
	}
	
	func add(message: MMGeoMessage) {
		messages.insert(message)
		addRegions(from: message)
	}
	
	func removeMessage(withId messageId: String) {
		removeRegions(withMessageId: messageId)
		messages.filter({
			return $0.messageId == messageId
		}).forEach {
			messages.remove($0)
		}
	}
	
    func reload() {
        loadMessages()
    }
    
//MARK: - Private
	
	private func loadMessages() {
		context.reset()
		context.performAndWait {
			let geomsgs = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageTypeValue == \(MMMessageType.Geo.rawValue)"), context: self.context)
			
			self.messages = Set(geomsgs?.flatMap({ return MMGeoMessage(managedObject: $0) }).filter { $0.isNotExpired } ?? [MMGeoMessage]())
		}
	}
	
	private func addRegions(from message: MMGeoMessage) {
		message.regions.forEach{ regionsDictionary[$0.dataSourceIdentifier] = $0 }
	}
	
	private func removeRegions(withMessageId messageId: String) {
		messages.filter({
			return $0.messageId == messageId
		}).forEach {
			$0.regions.forEach {
				regionsDictionary[$0.dataSourceIdentifier] = nil
			}
		}
	}
	
	private func regions(from campaigns: Set<MMGeoMessage>) -> [MMRegion] {
		return campaigns.reduce([MMRegion](), { (regions, message) -> [MMRegion] in
			return regions + message.regions
		})
	}
	
	private func validRegionsNow(for event: RegionEventType, with regionIdentifier: RegionIdentifier) -> [MMRegion]? {
		return messages.filter({ $0.isNowAppropriateTimeForNotification(for: event) }).flatMap{ $0.regions.filter({ $0.identifier == regionIdentifier }).first }
	}
}

