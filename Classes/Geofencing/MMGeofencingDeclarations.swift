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
@objcMembers
public final class MMLocationServiceKind: NSObject {
	let rawValue: Int
	init(rawValue: Int) { self.rawValue = rawValue }
	public init(options: [MMLocationServiceKind]) {
		let totalValue = options.reduce(0) { (total, option) -> Int in
			return total | option.rawValue
		}
		self.rawValue = totalValue
	}
	public func contains(options: MMLocationServiceKind) -> Bool {
		return rawValue & options.rawValue != 0
	}
	public static let locationUpdates = MMLocationServiceKind(rawValue: 0)
	public static let regionMonitoring = MMLocationServiceKind(rawValue: 1 << 0)
}

/// Describes the usage type for the location service. Possible values:
/// - When in Use
/// - Always
@objc public enum MMLocationServiceUsage: Int {
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
@objc public enum MMGeofencingCapabilityStatus: Int {
	case notDetermined
	case authorized
	case denied
	case notAvailable
}

public protocol MMGeofencingServiceDelegate: AnyObject {
	/// Called after the a new geo message is added to the service data source
	func didAddMessage(message: MMGeoMessage)
	/// Called after the user entered the region
	/// - parameter region: A particular region, that the user has entered
	func didEnterRegion(region: MMRegion)
	/// Called after the user exited the region
	/// - parameter region: A particular region, that the user has exited
	func didExitRegion(region: MMRegion)
}

struct GeoConstants {
	static let distanceFilter: CLLocationDistance = 100
	static let regionRefreshThreshold: CLLocationDistance = 200
	static let monitoringRegionsLimit: Int = 20
	static let preferableUsage = MMLocationServiceUsage.always
	static let minimumAllowedUsage = MMLocationServiceUsage.whenInUse
	static let supportedAuthStatuses = [CLAuthorizationStatus.authorizedWhenInUse, CLAuthorizationStatus.authorizedAlways]

	struct CampaignKeys {
		static let id = "id"
		static let title = "title"
		static let message = "message"
		static let dateReceived = "receivedDate"
		static let regions = "regions"
		static let origin = "origin"
		static let expiryDate = "expiryTime"
		static let startDate = "startTime"
		static let campaignId = "campaignId"
	}

	struct RegionKeys {
		static let latitude = "latitude"
		static let longitude = "longitude"
		static let radius = "radiusInMeters"
		static let title = "title"
		static let identifier = "id"
	}

	struct RegionDeliveryTimeKeys {
		static let days = "days"
		static let timeInterval = "timeInterval"
	}

	struct RegionEventKeys {
		static let type = "type"
		static let limit = "limit"
		static let timeout = "timeoutInMinutes"
		static let occuringCounter = "rate"
		static let lastOccur = "lastOccur"
	}
    
    struct UserDefaultsKey {
        static let geoEnabledFlag = "com.mobile-messaging.geofencing-enabled-flag"
    }
}

@objc public protocol MMGeoEventHandling {
	/// This callback is triggered after the geo event occurs. Default behaviour is implemented by `MMDefaultGeoEventHandling` class.
	func didEnter(region: MMRegion)
}
