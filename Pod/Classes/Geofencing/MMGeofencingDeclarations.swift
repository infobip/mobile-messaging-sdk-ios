//
//  MMGeofencingDeclarations.swift
//
//  Created by Andrey Kadochnikov on 14/04/2017.
//
//

import CoreLocation

/// Describes the kind of location service. Possible values:
/// - Location Updates
/// - Region Monitoring
public final class LocationServiceKind: NSObject {
	let rawValue: Int
	init(rawValue: Int) { self.rawValue = rawValue }
	public init(options: [LocationServiceKind]) {
		let totalValue = options.reduce(0) { (total, option) -> Int in
			return total | option.rawValue
		}
		self.rawValue = totalValue
	}
	public func contains(options: LocationServiceKind) -> Bool {
		return rawValue & options.rawValue != 0
	}
	public static let locationUpdates = LocationServiceKind(rawValue: 0)
	public static let regionMonitoring = LocationServiceKind(rawValue: 1 << 0)
}

/// Describes the usage type for the location service. Possible values:
/// - When in Use
/// - Always
@objc public enum LocationServiceUsage: Int {
	/// This app is authorized to start most location services while running in the foreground.
	case whenInUse
	/// This app is authorized to start location services at any time.
	case always
}

/// Describes the capability status for Geofencing Service. Possible values:
/// - `notDetermined`: The capability has not been requested yet
/// - `authorized`: The capability has been requested and approved
/// - `denied`: The capability has been requested but was denied by the user
/// - `notAvailable`: The capability is not available (perhaps due to restrictions, or lack of support)
@objc public enum GeofencingCapabilityStatus: Int {
	case notDetermined
	case authorized
	case denied
	case notAvailable
}

public protocol MMGeofencingServiceDelegate: class {
	/// Called after the a new geo message is added to the service data source
	func didAddMessage(message: MMGeoMessage)
	/// Called after the user entered the region
	/// - parameter region: A particular region, that the user has entered
	func didEnterRegion(region: MMRegion)
	/// Called after the user exited the region
	/// - parameter region: A particular region, that the user has exited
	func didExitRegion(region: MMRegion)
}

struct GeofencingConstants {
	static let distanceFilter: CLLocationDistance = 100
	static let regionRefreshThreshold: CLLocationDistance = 200
	static let monitoringRegionsLimit: Int = 20
	static let preferableUsage = LocationServiceUsage.always
	static let minimumAllowedUsage = LocationServiceUsage.whenInUse
	static let supportedAuthStatuses = [CLAuthorizationStatus.authorizedWhenInUse, CLAuthorizationStatus.authorizedAlways]
}

@objc public protocol GeoEventHandling {
	/// This callback is triggered after the geo event occurs. Default behaviour is implemented by `MMDefaultGeoEventHandling` class.
	func didEnter(region: MMRegion)
}

struct GeoEventReportingRequest: PostRequest {
	typealias ResponseType = GeoEventReportingResponse
	
	var path: APIPath { return .GeoEventsReports }
	var body: RequestBody? {
		return [
			PushRegistration.platform: APIValues.platformType,
			PushRegistration.internalId: internalUserId,
			GeoReportingAPIKeys.reports: eventsDataList.map { $0.dictionaryRepresentation },
			GeoReportingAPIKeys.messages: geoMessages.map { $0.geoEventReportFormat }
		]
	}
	
	let internalUserId: String
	let eventsDataList: [GeoEventReportData]
	let geoMessages: [MMGeoMessage]
	
	init(internalUserId: String, eventsDataList: [GeoEventReportData], geoMessages: [MMGeoMessage]) {
		self.internalUserId = internalUserId
		self.eventsDataList = eventsDataList
		self.geoMessages = geoMessages
	}
}

