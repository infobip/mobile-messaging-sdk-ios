//
//  MMGeoRequests.swift
//
//  Created by okoroleva on 19.04.17.
//
//

import Foundation

public struct GeoEventReportData: DictionaryRepresentable {
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
	
    public init?(dictRepresentation dict: DictionaryRepresentation) {
		return nil // unused
	}
	
    public var dictionaryRepresentation: DictionaryRepresentation {
		return [MMConsts.GeoReportingAPIKeys.campaignId: campaignId,
                MMConsts.GeoReportingAPIKeys.timestampDelta: eventDate.timestampDelta,
                MMConsts.GeoReportingAPIKeys.geoAreaId: geoAreaId,
                MMConsts.GeoReportingAPIKeys.event: eventType.rawValue,
                MMConsts.GeoReportingAPIKeys.messageId: messageId,
                MMConsts.GeoReportingAPIKeys.sdkMessageId: sdkMessageId
		]
	}
}

class GeoEventReportingRequest: PostRequest {
	typealias ResponseType = GeoEventReportingResponse

    init(applicationCode: String, pushRegistrationId: String, eventsDataList: [GeoEventReportData], geoMessages: [MMGeoMessage]) {
        super.init(applicationCode: applicationCode, path: .GeoEventsReports, pushRegistrationId: pushRegistrationId, body: [
            MMConsts.PushRegistration.platform: MMConsts.APIValues.platformType,
            MMConsts.PushRegistration.internalId: pushRegistrationId,
            MMConsts.GeoReportingAPIKeys.reports: eventsDataList.map { $0.dictionaryRepresentation },
            MMConsts.GeoReportingAPIKeys.messages: geoMessages.map { $0.geoEventReportFormat }
        ])
	}
}

class GeoRemoteAPIProvider : SessionManagement {
	var sessionManager: DynamicBaseUrlHTTPSessionManager

	init(sessionManager: DynamicBaseUrlHTTPSessionManager) {
		self.sessionManager = sessionManager
	}
	
    func reportGeoEvent(applicationCode: String, pushRegistrationId: String, eventsDataList: [GeoEventReportData], geoMessages: [MMGeoMessage], queue: DispatchQueue, completion: @escaping (GeoEventReportingResult) -> Void) {
		let request = GeoEventReportingRequest(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, eventsDataList: eventsDataList, geoMessages: geoMessages)
        performRequest(request: request, queue: queue, completion: completion)
	}
}
