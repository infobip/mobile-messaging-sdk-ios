//
//  MMGeoRequests.swift
//
//  Created by okoroleva on 19.04.17.
//
//

struct GeoEventReportData: DictionaryRepresentable {
	let campaignId: String
	let eventDate: Date
	let geoAreaId: String
	let messageId: String
	let sdkMessageId: String
	let eventType: RegionEventType
	
	init(geoAreaId: String, eventType: RegionEventType, campaignId: String, eventDate: Date, sdkMessageId: String, messageId: String) {
		self.campaignId = campaignId
		self.eventDate = eventDate
		self.geoAreaId = geoAreaId
		self.eventType = eventType
		self.messageId = messageId
		self.sdkMessageId = sdkMessageId
	}
	
	init?(dictRepresentation dict: DictionaryRepresentation) {
		return nil // unused
	}
	
	var dictionaryRepresentation: DictionaryRepresentation {
		return [GeoReportingAPIKeys.campaignId: campaignId,
		        GeoReportingAPIKeys.timestampDelta: eventDate.timestampDelta,
		        GeoReportingAPIKeys.geoAreaId: geoAreaId,
		        GeoReportingAPIKeys.event: eventType.rawValue,
		        GeoReportingAPIKeys.messageId: messageId,
		        GeoReportingAPIKeys.sdkMessageId: sdkMessageId
		]
	}
}
