//
//  GeoDatesUtils.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 05/03/2018.
//

import Foundation

extension MMGeofencingService {
	@nonobjc static var currentDate: Date? // @nonobjc is to shut up the "A declaration cannot be both 'final' and 'dynamic'" error
	
	static func isGeoCampaignNotExpired(campaign: MMGeoMessage) -> Bool {
		let now = MMGeofencingService.currentDate ?? MobileMessaging.date.now
		
		return campaign.campaignState == .Active && now.compare(campaign.expiryTime) == .orderedAscending && campaign.hasValidEventsStateInGeneral
	}
	
	static func isNowAppropriateDay(forDeliveryTime dt: MMDeliveryTime) -> Bool {
		guard let days = dt.days, !days.isEmpty else {
			return true
		}
		let now = MMGeofencingService.currentDate ?? MobileMessaging.date.now
		let calendar = MobileMessaging.calendar
		let comps = calendar.dateComponents(in: MobileMessaging.timeZone, from: now)
		if let systemWeekDay = comps.weekday {
			let isoWeekdayNumber = systemWeekDay == 1 ? 7 : Int8(systemWeekDay - 1)
			if let day = MMDay(rawValue: isoWeekdayNumber) {
				return days.contains(day)
			} else {
				return false
			}
		}
		return false
	}
	
	static func isNowAppropriateTime(forDeliveryTimeInterval dti: MMDeliveryTimeInterval) -> Bool {
		let now = MMGeofencingService.currentDate ?? MobileMessaging.date.now
		return MMDeliveryTimeInterval.isTime(now, between: dti.fromTime, and: dti.toTime)
	}
	
	static func isRegionEventValidNow(_ regionEvent: RegionEvent) -> Bool {
		guard MMGeofencingService.isRegionEventValidInGeneral(regionEvent) else {
			return false
		}
		let now = MMGeofencingService.currentDate ?? MobileMessaging.date.now
		return regionEvent.lastOccuring?.addingTimeInterval(TimeInterval(regionEvent.timeout * 60)).compare(now) != .orderedDescending
	}
	
	static func isRegionEventValidInGeneral(_ regionEvent: RegionEvent) -> Bool {
		return !regionEvent.hasReachedTheOccuringLimit
	}
}
