//
//  MMGeofencingService.swift
//
//  Created by Ivan Cigic on 06/07/16.
//
//

import Foundation
import CoreLocation
import UIKit

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
	public static let LocationUpdates = MMLocationServiceKind(rawValue: 0)
	public static let RegionMonitoring = MMLocationServiceKind(rawValue: 1 << 0)
}

@objc public enum MMLocationServiceUsage: Int {
	case WhenInUse
	case Always
}

@objc public enum MMCapabilityStatus: Int {
	/// The capability has not been requested yet
	case NotDetermined
	/// The capability has been requested and approved
	case Authorized
	/// The capability has been requested but was denied by the user
	case Denied
	/// The capability is not available (perhaps due to restrictions, or lack of support)
	case NotAvailable
}

public protocol MMGeofencingServiceDelegate: class {
	func didAddCampaing(_ campaign: MMCampaign)
	func didEnterRegion(_ region: MMRegion)
	func didExitRegion(_ region: MMRegion)
}

public class MMGeofencingService: NSObject, CLLocationManagerDelegate {
	let kDistanceFilter: CLLocationDistance = 100
	
	static let sharedInstance = MMGeofencingService()
	var locationManager: CLLocationManager!
	var datasource: MMGeofencingDatasource!
	var isRunning = false
	
	// MARK: - Public
	private var _locationManagerEnabled = true
	public var locationManagerEnabled: Bool {
		set {
			if newValue != locationManagerEnabled && newValue == false {
				stop()
			}
		}
		get {
			return _locationManagerEnabled
		}
	}
	
	public var currentUserLocation: CLLocation? { return locationManager.location }
	public weak var delegate: MMGeofencingServiceDelegate?
	public var allCampaings: Set<MMCampaign> { return datasource.campaigns }
	public var allRegions: Set<MMRegion> { return Set(datasource.regions.values) }
	
	class var currentCapabilityStatus: MMCapabilityStatus {
		return MMGeofencingService.currentCapabilityStatusForService(MMLocationServiceKind.RegionMonitoring, usage: .Always)
	}

	public func authorize(usage: MMLocationServiceUsage, completion: @escaping (MMCapabilityStatus) -> Void) {
		authorizeService(MMLocationServiceKind.RegionMonitoring, usage: usage, completion: completion)
	}

	public func start(_ completion: ((Bool) -> Void)? = nil) {
		serviceQueue.executeAsync() {
			MMLogDebug("[GeofencingService] starting ...")
			guard self.locationManagerEnabled == true && self.isRunning == false else
			{
				MMLogDebug("[GeofencingService] locationManagerEnabled = \(self.locationManagerEnabled), isRunning = \(self.isRunning))")
				completion?(false)
				return
			}
			
			let currentCapability = MMGeofencingService.currentCapabilityStatus
			switch currentCapability {
			case .Authorized:
				self.startService()
				completion?(true)
			case .NotDetermined:
				MMLogDebug("[GeofencingService] capability is 'not determined', authorizing...")
				self.authorizeService(MMLocationServiceKind.RegionMonitoring, usage: .Always) { status in
					switch status {
					case .Authorized:
						MMLogDebug("[GeofencingService] successfully authorized")
						self.startService()
						completion?(true)
					default:
						MMLogDebug("[GeofencingService] was not authorized. Canceling the startup.")
						completion?(false)
						break
					}
				}
			case .Denied, .NotAvailable:
				MMLogDebug("[GeofencingService] capability is \(currentCapability). Canceling the startup.")
				completion?(false)
			}
		}
	}
	
	public func stop() {
		serviceQueue.executeAsync() {
			guard self.isRunning == true else
			{
				return
			}
			self.isRunning = false
			self.locationManager.delegate = nil
			self.locationManager.stopMonitoringSignificantLocationChanges()
			self.locationManager.stopUpdatingLocation()
			self.stopMonitoringMonitoredRegions()
			NotificationCenter.default.removeObserver(self)
			MMLogDebug("[GeofencingService] stopped.")
		}
	}
	
	public func addCampaingToRegionMonitoring(_ campaign: MMCampaign) {
		serviceQueue.executeAsync() {
			MMLogDebug("[GeofencingService] trying to add a campaign")
			guard self.locationManagerEnabled == true && self.isRunning == true else
			{
				MMLogDebug("[GeofencingService] locationManagerEnabled = \(self.locationManagerEnabled), isRunning = \(self.isRunning))")
				return
			}
			
			self.datasource.addNewCampaign(campaign)
			self.delegate?.didAddCampaing(campaign)
			MMLogDebug("[GeofencingService] added a campaign\n\(campaign)")
			self.refreshMonitoredRegions()
		}
	}
	
	public func removeCampaignFromRegionMonitoring(_ campaing: MMCampaign) {
		serviceQueue.executeAsync() {
			self.datasource.removeCampaign(campaing)
			MMLogDebug("[GeofencingService] campaign removed \(campaing)")
			self.refreshMonitoredRegions()
		}
	}
	
	// MARK: - Internal
	let serviceQueue = MMQueue.Main.queue
	
	override init () {
		super.init()
		serviceQueue.executeAsync() {
			self.locationManager = CLLocationManager()
			self.locationManager.delegate = self
			self.datasource = MMGeofencingDatasource()
		}
	}
	
	class var isWhenInUseDescriptionProvided: Bool {
		return Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") != nil
	}
	
	class var isAlwaysDescriptionProvided: Bool {
		return Bundle.main.object(forInfoDictionaryKey: "NSLocationAlwaysUsageDescription") != nil
	}
	
	func authorizeService(_ kind: MMLocationServiceKind, usage: MMLocationServiceUsage, completion: @escaping (MMCapabilityStatus) -> Void) {
		serviceQueue.executeAsync() {
			guard self.completion == nil else
			{
				fatalError("Attempting to authorize location when a request is already in-flight")
			}
			
			let locationServicesEnabled = CLLocationManager.locationServicesEnabled()
			let regionMonitoringAvailable = CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self)
			guard locationServicesEnabled && (!kind.contains(options: MMLocationServiceKind.RegionMonitoring) || regionMonitoringAvailable) else
			{
				MMLogDebug("[GeofencingService] not available (locationServicesEnabled = \(locationServicesEnabled), regionMonitoringAvailable = \(regionMonitoringAvailable))")
				completion(.NotAvailable)
				return
			}
			
			self.completion = completion
			self.usageKind = usage
		
			switch usage {
			case .WhenInUse:
				MMLogDebug("[GeofencingService] requesting 'WhenInUse'")
				
				if !MMGeofencingService.isWhenInUseDescriptionProvided {
					MMLogDebug("[GeofencingService] NSLocationWhenInUseUsageDescription is not defined. Geo service cannot be used")
					completion(.NotAvailable)
				} else {
					self.locationManager.requestWhenInUseAuthorization()
				}
			case .Always:
				MMLogDebug("[GeofencingService] requesting 'Always'")
				
				if !MMGeofencingService.isAlwaysDescriptionProvided {
					MMLogDebug("[GeofencingService] NSLocationAlwaysUsageDescription is not defined. Geo service cannot be used")
					completion(.NotAvailable)
				} else {
					self.locationManager.requestAlwaysAuthorization()
				}
			}
			
			// This is helpful when developing an app.
//			assert(NSBundle.mainBundle().objectForInfoDictionaryKey(key) != nil, "Requesting location permission requires the \(key) key in your Info.plist")
		}
	}
	
	// MARK: - Private
	private var usageKind = MMLocationServiceUsage.WhenInUse
	
	private var completion: ((MMCapabilityStatus) -> Void)?
	
	private func startService() {
		serviceQueue.executeAsync() {
			guard self.locationManagerEnabled == true && self.isRunning == false else
			{
				return
			}
			MMLogDebug("[GeofencingService] started.")
			self.locationManager.distanceFilter = self.kDistanceFilter
			self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
			self.locationManager.startUpdatingLocation()
			
			NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationWillResignActive, object: nil, queue: nil, using:
				{ [weak self] note in
					assert(Thread .isMainThread)
					self?.locationManager.stopUpdatingLocation()
					if CLLocationManager.significantLocationChangeMonitoringAvailable() {
						self?.locationManager.startMonitoringSignificantLocationChanges()
					} else {
						MMLogDebug("[GeofencingService] Significant location change monitoring is not available.")
					}
				}
			)
			
			NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationWillEnterForeground, object: nil, queue: nil, using:
				{ [weak self] note in
					assert(Thread .isMainThread)
					if CLLocationManager.significantLocationChangeMonitoringAvailable() {
						self?.locationManager.stopMonitoringSignificantLocationChanges()
					}
					self?.locationManager.startUpdatingLocation()
				}
			)
			self.isRunning = true
			self.refreshMonitoredRegions()
		}
	}
	
	private func stopMonitoringMonitoredRegions() {
		serviceQueue.executeAsync() {
			MMLogDebug("[GeofencingService] stopping monitoring all regions")
			for monitoredRegion in self.locationManager.monitoredRegions {
				self.locationManager.stopMonitoring(for: monitoredRegion)
			}
		}
	}
	
	private func refreshMonitoredRegions() {
		serviceQueue.executeAsync() {
			MMLogDebug("[GeofencingService] datasource regions: \n\(self.datasource.regions.values)")
			
			MMLogDebug("[GeofencingService] refreshing regions...")
			
			var currentlyMonitoredRegions: Set<CLCircularRegion> = Set(self.locationManager.monitoredRegions.flatMap {$0 as? CLCircularRegion})
			MMLogDebug("[GeofencingService] currently monitored regions \n\(currentlyMonitoredRegions)")
			
			let regionsWeAreInside: Set<CLCircularRegion> = Set(currentlyMonitoredRegions.filter {
				if let currentCoordinate = self.locationManager.location?.coordinate {
					return $0.contains(currentCoordinate)
				} else {
					return false
				}
			})
			MMLogDebug("[GeofencingService] regions we are inside: \n\(regionsWeAreInside)")

			let expiredRegions: Set<CLCircularRegion> = Set(currentlyMonitoredRegions.filter {
				return self.datasource.regions[$0.identifier]?.isExpired ?? true
			})
			MMLogDebug("[GeofencingService] expired monitored regions: \n\(expiredRegions)")
            currentlyMonitoredRegions.subtract(regionsWeAreInside)
			let regionsToStopMonitoring = currentlyMonitoredRegions.union(expiredRegions)
			MMLogDebug("[GeofencingService] regions to stop monitoring: \n\(regionsToStopMonitoring)")
			
			for region in regionsToStopMonitoring {
				self.locationManager.stopMonitoring(for: region)
			}
			let datasourceRegions = Set(self.datasource.notExpiredRegions.flatMap { $0.circularRegion })
			let regionsToStartMonitoring = Set(MMGeofencingService.findClosestRegions(20 - self.locationManager.monitoredRegions.count, fromLocation: self.locationManager.location, fromRegions: datasourceRegions, filter: { self.locationManager.monitoredRegions.contains($0) == false }))
			
			MMLogDebug("[GeofencingService] regions to start monitoring: \n\(regionsToStartMonitoring)")

			for region in regionsToStartMonitoring {
				region.notifyOnEntry = true
				region.notifyOnExit = true
				self.locationManager.startMonitoring(for: region)
				
				//check if aleady in region
				if let currentCoordinate = self.locationManager.location?.coordinate , region.contains(currentCoordinate) {
					MMLogDebug("[GeofencingService] detected a region in which we currently are \(region)")
					self.locationManager(self.locationManager, didEnterRegion: region)
				}
			}
		}
	}
	
	class func findClosestRegions(_ number: Int, fromLocation: CLLocation?, fromRegions regions: Set<CLCircularRegion>, filter: ((CLCircularRegion) -> Bool)?) ->  [CLCircularRegion] {
		let filterPredicate: (CLCircularRegion) -> Bool = filter == nil ? { (_: CLCircularRegion) -> Bool in return true } : filter!
		var filteredRegions: [CLCircularRegion] = Array(regions).filter(filterPredicate)
		
		if let fromLocation = fromLocation {
			filteredRegions.sort(by: { (region1, region2) in
				let region1Location = CLLocation(latitude: region1.center.latitude, longitude: region1.center.longitude)
				let region2Location = CLLocation(latitude: region2.center.latitude, longitude: region2.center.longitude)
				return fromLocation.distance(from: region1Location) < fromLocation.distance(from: region2Location)
			}) 
			return Array(filteredRegions[0..<min(number, filteredRegions.count)])
		} else {
			return Array(filteredRegions[0..<min(number, filteredRegions.count)])
		}
	}
	
	class func currentCapabilityStatusForService(_ kind: MMLocationServiceKind, usage: MMLocationServiceUsage) -> MMCapabilityStatus {
		guard CLLocationManager.locationServicesEnabled() && (!kind.contains(options: MMLocationServiceKind.RegionMonitoring) || CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self)) else
		{
			return .NotAvailable
		}
		
		if (usage == .WhenInUse && !MMGeofencingService.isWhenInUseDescriptionProvided) || (usage == .Always && !MMGeofencingService.isAlwaysDescriptionProvided) {
			return .NotAvailable
		}
		
		switch CLLocationManager.authorizationStatus() {
		case .notDetermined: return .NotDetermined
		case .restricted: return .NotAvailable
		case .denied: return .Denied
		case .authorizedAlways: return .Authorized
		case .authorizedWhenInUse:
			if usage == MMLocationServiceUsage.WhenInUse {
				return .Authorized
			} else {
				// the user wants .Always, but has .WhenInUse
				// return .NotDetermined so that we can prompt to upgrade the permission
				return .NotDetermined
			}
		}
	}
	
	private func shouldRefreshRegions() -> Bool {
		let monitorableRegionsCount = self.datasource.notExpiredRegions.count
		return monitorableRegionsCount > 20
	}
	
	// MARK: - Location Manager delegate
	public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
		assert(Thread.isMainThread)
		MMLogDebug("[GeofencingService] locationManager did change the authorization status \(status.rawValue)")
		if let completion = self.completion , manager == self.locationManager && status != .notDetermined {
			self.completion = nil
			
			switch status {
			case .authorizedAlways:
				completion(.Authorized)
			case .authorizedWhenInUse:
				completion(self.usageKind == .WhenInUse ? .Authorized : .Denied)
			case .denied:
				completion(.Denied)
			case .restricted:
				completion(.NotAvailable)
			case .notDetermined:
				fatalError("Unreachable due to the if statement, but included to keep clang happy")
			}
		}
		
		if self.isRunning {
			switch status {
			case .authorizedWhenInUse, .denied, .restricted, .notDetermined:
				stop()
			default:
				break
			}
		} else {
			switch status {
			case .authorizedAlways:
				startService()
			default:
				break
			}
		}
	}
	
	public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
		assert(Thread.isMainThread)
		MMLogDebug("[GeofencingService] did enter circular region \(region)")
		if let datasourceRegion = datasource.regions[region.identifier] , datasourceRegion.isExpired == false {
			MMLogDebug("[GeofencingService] did enter datasource region \(datasourceRegion)")
			delegate?.didEnterRegion(datasourceRegion)
			NotificationCenter.mm_postNotificationFromMainThread(name: MMNotificationGeographicalRegionDidEnter, userInfo: [MMNotificationKeyGeographicalRegion: datasourceRegion])
		} else {
			MMLogDebug("[GeofencingService] region is expired.")
		}
	}
	
	public func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
		assert(Thread.isMainThread)
		MMLogDebug("[GeofencingService] did start monitoring \(region)")
	}
	
	public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
		assert(Thread.isMainThread)
		MMLogDebug("[GeofencingService] did exit circular region \(region)")
		if let datasourceRegion = datasource.regions[region.identifier] , datasourceRegion.isExpired == false {
			MMLogDebug("[GeofencingService] did exit datasource region \(datasourceRegion)")
			delegate?.didExitRegion(datasourceRegion)
			NotificationCenter.mm_postNotificationFromMainThread(name: MMNotificationGeographicalRegionDidExit, userInfo: [MMNotificationKeyGeographicalRegion: datasourceRegion])
		} else {
			MMLogDebug("[GeofencingService] region is expired.")
		}
	}
	
	public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
		assert(Thread.isMainThread)
		MMLogDebug("[GeofencingService] did fail with error \(error)")
	}
	
	public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		assert(Thread.isMainThread)
		MMLogDebug("[GeofencingService] did update locations")
		if self.shouldRefreshRegions() {
			self.refreshMonitoredRegions()
		}
	}
}
