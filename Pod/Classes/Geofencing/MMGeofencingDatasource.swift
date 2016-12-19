//
//  MMGeofencingDatasource.swift
//
//  Created by Ivan Cigic on 06/07/16.
//
//

import Foundation
import CoreLocation
import CoreData

class MMGeofencingDatasource {
	
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
		loadMessages()
	}
	
	func validRegionsForEntryEvent(with regionIdentifier: RegionIdentifier) -> [MMRegion]? {
		return validRegions(for: .entry, with: regionIdentifier)
	}
	
	func validRegionsForExitEvent(with regionIdentifier: RegionIdentifier) -> [MMRegion]? {
		return validRegions(for: .exit, with: regionIdentifier)
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
	
//MARK: - Private
	
	private func loadMessages() {
		context.performAndWait {
			let msgs = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageTypeValue == %i", MMMessageType.Geo.rawValue), context: self.context)
			
			self.messages = Set(msgs?.flatMap(MMGeoMessage.init).filter({ $0.isNotExpired }) ?? [MMGeoMessage]())
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
	
	private func validRegions(for event: MMRegionEventType, with regionIdentifier: RegionIdentifier) -> [MMRegion]? {
		return messages.filter({ $0.isNowAppropriateTimeForNotification(for: event) }).flatMap{ $0.regions.filter({ $0.identifier == regionIdentifier }).first }
	}
}

