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

struct GeoEventReportingRequest: PostRequest {
	var applicationCode: String
	var pushRegistrationId: String?
	typealias ResponseType = GeoEventReportingResponse
	var path: APIPath { return .GeoEventsReports }
	var body: RequestBody? {
		return [
			Consts.PushRegistration.platform: Consts.APIValues.platformType,
			Consts.PushRegistration.internalId: pushRegistrationId ?? "n/a",
			Consts.GeoReportingAPIKeys.reports: eventsDataList.map { $0.dictionaryRepresentation },
			Consts.GeoReportingAPIKeys.messages: geoMessages.map { $0.geoEventReportFormat }
		]
	}

	let eventsDataList: [GeoEventReportData]
	let geoMessages: [MMGeoMessage]

	init(applicationCode: String, pushRegistrationId: String, eventsDataList: [GeoEventReportData], geoMessages: [MMGeoMessage]) {
		self.applicationCode = applicationCode
		self.pushRegistrationId = pushRegistrationId
		self.eventsDataList = eventsDataList
		self.geoMessages = geoMessages
	}
}

protocol GeoRemoteAPIProtocol: SessionManagement {
	func reportGeoEvent(applicationCode: String, pushRegistrationId: String, eventsDataList: [GeoEventReportData], geoMessages: [MMGeoMessage], completion: @escaping (GeoEventReportingResult) -> Void)
}


class GeoRemoteAPIProvider : GeoRemoteAPIProtocol {
	var sessionManager: DynamicBaseUrlHTTPSessionManager

	init(sessionManager: DynamicBaseUrlHTTPSessionManager) {
		self.sessionManager = sessionManager
	}
	
	func reportGeoEvent(applicationCode: String, pushRegistrationId: String, eventsDataList: [GeoEventReportData], geoMessages: [MMGeoMessage], completion: @escaping (GeoEventReportingResult) -> Void) {
		let request = GeoEventReportingRequest(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, eventsDataList: eventsDataList, geoMessages: geoMessages)
		performRequest(request: request, completion: completion)
	}
}
