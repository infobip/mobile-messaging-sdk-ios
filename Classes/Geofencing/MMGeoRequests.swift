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
		return [Consts.GeoReportingAPIKeys.campaignId: campaignId,
		        Consts.GeoReportingAPIKeys.timestampDelta: eventDate.timestampDelta,
		        Consts.GeoReportingAPIKeys.geoAreaId: geoAreaId,
		        Consts.GeoReportingAPIKeys.event: eventType.rawValue,
		        Consts.GeoReportingAPIKeys.messageId: messageId,
		        Consts.GeoReportingAPIKeys.sdkMessageId: sdkMessageId
		]
	}
}

class GeoEventReportingRequest: PostRequest {
	typealias ResponseType = GeoEventReportingResponse

	init(applicationCode: String, pushRegistrationId: String, eventsDataList: [GeoEventReportData], geoMessages: [MMGeoMessage]) {
		super.init(applicationCode: applicationCode, path: .GeoEventsReports, pushRegistrationId: pushRegistrationId, body: [
			Consts.PushRegistration.platform: Consts.APIValues.platformType,
			Consts.PushRegistration.internalId: pushRegistrationId,
			Consts.GeoReportingAPIKeys.reports: eventsDataList.map { $0.dictionaryRepresentation },
			Consts.GeoReportingAPIKeys.messages: geoMessages.map { $0.geoEventReportFormat }
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
