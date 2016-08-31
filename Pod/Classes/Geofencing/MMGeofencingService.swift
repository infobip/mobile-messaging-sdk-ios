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

public enum MMLocationServiceUsage: Int {
	case WhenInUse
	case Always
}

public enum MMCapabilityStatus: Int {
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
	func didAddCampaing(campaign: MMCampaign)
	func didEnterRegion(region: MMRegion)
	func didExitRegion(region: MMRegion)
}

public class MMGeofencingService: NSObject, CLLocationManagerDelegate {
	let kDistanceFilter: CLLocationDistance = 100
	let kMonitoringRegionsLimit: Int = 20
	
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

	public func authorize(usage: MMLocationServiceUsage, completion: MMCapabilityStatus -> Void) {
		authorizeService(MMLocationServiceKind.RegionMonitoring, usage: usage, completion: completion)
	}

	public func start(completion: (Bool -> Void)? = nil) {
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
			NSNotificationCenter.defaultCenter().removeObserver(self)
			MMLogDebug("[GeofencingService] stopped.")
		}
	}
	
	public func addCampaingToRegionMonitoring(campaign: MMCampaign) {
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
	
	public func removeCampaignFromRegionMonitoring(campaing: MMCampaign) {
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
			self.locationManager.distanceFilter = self.kDistanceFilter
			self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
			self.datasource = MMGeofencingDatasource()
			
			self.previousLocation = NSKeyedUnarchiver.unarchiveObjectWithFile(self.datasource.locationArchivePath) as? CLLocation
		}
	}
	
	class var isWhenInUseDescriptionProvided: Bool {
		return NSBundle.mainBundle().objectForInfoDictionaryKey("NSLocationWhenInUseUsageDescription") != nil
	}
	
	class var isAlwaysDescriptionProvided: Bool {
		return NSBundle.mainBundle().objectForInfoDictionaryKey("NSLocationAlwaysUsageDescription") != nil
	}
	
	func authorizeService(kind: MMLocationServiceKind, usage: MMLocationServiceUsage, completion: MMCapabilityStatus -> Void) {
		serviceQueue.executeAsync() {
			guard self.completion == nil else
			{
				fatalError("Attempting to authorize location when a request is already in-flight")
			}
			
			let locationServicesEnabled = CLLocationManager.locationServicesEnabled()
			let regionMonitoringAvailable = CLLocationManager.isMonitoringAvailableForClass(CLCircularRegion)
			guard locationServicesEnabled && (!kind.contains(MMLocationServiceKind.RegionMonitoring) || regionMonitoringAvailable) else
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
	
	private var completion: (MMCapabilityStatus -> Void)?
	
	private func restartLocationManager() {
		if UIApplication.sharedApplication().applicationState == UIApplicationState.Active {
			if CLLocationManager.significantLocationChangeMonitoringAvailable() {
				self.locationManager.stopMonitoringSignificantLocationChanges()
				MMLogDebug("[GeofencingService] stopped updating significant location changes")
			}
			self.locationManager.startUpdatingLocation()
			MMLogDebug("[GeofencingService] started updating location")
		} else {
			self.locationManager.stopUpdatingLocation()
			MMLogDebug("[GeofencingService] stopped updating location")
			if CLLocationManager.significantLocationChangeMonitoringAvailable() {
				self.locationManager.startMonitoringSignificantLocationChanges()
				MMLogDebug("[GeofencingService] started updating significant location changes")
			}
		}
	}
	
	private func startService() {
		serviceQueue.executeAsync() {
			guard self.locationManagerEnabled == true && self.isRunning == false else
			{
				return
			}
			
			self.restartLocationManager()
			self.refreshMonitoredRegions()
			
			NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationDidFinishLaunchingNotification, object: nil, queue: nil, usingBlock:
				{ [weak self] notification in
					assert(NSThread .isMainThread())
					if notification.userInfo?[UIApplicationLaunchOptionsLocationKey] != nil {
						MMLogDebug("[GeofencingService] The app relaunched by the OS.")
						self?.restartLocationManager()
					}
				}
			)
			
			NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationDidEnterBackgroundNotification, object: nil, queue: nil, usingBlock:
				{ [weak self] notification in
					MMLogDebug("[GeofencingService] App did enter background.")
					assert(NSThread .isMainThread())
					self?.restartLocationManager()
					if let previousLocation = self?.previousLocation, let filePath = self?.datasource.locationArchivePath {
						NSKeyedArchiver.archiveRootObject(previousLocation, toFile: filePath)
					}
				}
			)
			
			NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationDidBecomeActiveNotification, object: nil, queue: nil, usingBlock:
				{ [weak self] note in
					MMLogDebug("[GeofencingService] App did become active.")
					assert(NSThread .isMainThread())
					self?.restartLocationManager()
				}
			)
			
			self.isRunning = true
			MMLogDebug("[GeofencingService] started.")
		}
	}
	
	private func stopMonitoringMonitoredRegions() {
		serviceQueue.executeAsync() {
			MMLogDebug("[GeofencingService] stopping monitoring all regions")
			for monitoredRegion in self.locationManager.monitoredRegions {
				self.locationManager.stopMonitoringForRegion(monitoredRegion)
			}
		}
	}
	
	private func refreshMonitoredRegions() {
		serviceQueue.executeAsync() {
			MMLogDebug("[GeofencingService] refreshing regions...")
			
			let closestNotExpiredRegions = self.findClosestNotExpiredRegions
			MMLogDebug("[GeofencingService] datasource regions: \n\(self.datasource.regions.values)")

			let currentlyMonitoredRegions: Set<CLCircularRegion> = Set(self.locationManager.monitoredRegions.flatMap {$0 as? CLCircularRegion})
			MMLogDebug("[GeofencingService] currently monitored regions \n\(currentlyMonitoredRegions.flatMap { return self.datasource.regions[$0.identifier] })")
			
			let regionsWeAreInside: Set<CLCircularRegion> = Set(currentlyMonitoredRegions.filter {
					if let currentCoordinate = self.locationManager.location?.coordinate {
						return $0.containsCoordinate(currentCoordinate)
					} else {
						return false
					}
				}
			)
			MMLogDebug("[GeofencingService] regions we are inside: \n\(regionsWeAreInside.flatMap { return self.datasource.regions[$0.identifier] })")
			
			let expiredRegions: Set<CLCircularRegion> = Set(currentlyMonitoredRegions.filter {
					return self.datasource.regions[$0.identifier]?.isExpired ?? true
				}
			)
			MMLogDebug("[GeofencingService] expired monitored regions: \n\(expiredRegions.flatMap { return self.datasource.regions[$0.identifier] })")
			
			let regionsToStopMonitoring = currentlyMonitoredRegions.subtract(regionsWeAreInside).union(expiredRegions)
			MMLogDebug("[GeofencingService] regions to stop monitoring: \n\(regionsToStopMonitoring.flatMap { return self.datasource.regions[$0.identifier] })")
			
			for region in regionsToStopMonitoring {
				self.locationManager.stopMonitoringForRegion(region)
			}
			
			MMLogDebug("[GeofencingService] regions to start monitoring: \n\(closestNotExpiredRegions.flatMap { return self.datasource.regions[$0.identifier] })")

			for region in closestNotExpiredRegions {
				region.notifyOnEntry = true
				region.notifyOnExit = true
				self.locationManager.startMonitoringForRegion(region)
				
				//check if aleady in region
				if let currentCoordinate = self.locationManager.location?.coordinate where region.containsCoordinate(currentCoordinate) {
					MMLogDebug("[GeofencingService] detected a region in which we currently are \(self.datasource.regions[region.identifier])")
					self.locationManager(self.locationManager, didEnterRegion: region)
				}
			}
		}
	}
	
	var findClosestNotExpiredRegions: Set<CLCircularRegion> {
		let notExpiredRegions = Set(self.datasource.notExpiredRegions.flatMap { $0.circularRegion })
		let number = self.kMonitoringRegionsLimit - self.locationManager.monitoredRegions.count
		let location = self.locationManager.location ?? previousLocation
		let array = MMGeofencingService.findClosestRegions(number, fromLocation: location, fromRegions: notExpiredRegions, filter: { self.locationManager.monitoredRegions.contains($0) == false })
		return Set(array)
	}
	
	class func findClosestRegions(number: Int, fromLocation: CLLocation?, fromRegions regions: Set<CLCircularRegion>, filter: (CLCircularRegion -> Bool)?) -> [CLCircularRegion] {
		
		let number = Int(max(0, number))
		guard number > 0 else
		{
			return []
		}
		
		let filterPredicate: CLCircularRegion -> Bool = filter == nil ? { (_: CLCircularRegion) -> Bool in return true } : filter!
		let filteredRegions: [CLCircularRegion] = Array(regions).filter(filterPredicate)
		
		if let fromLocation = fromLocation {
			let sortedRegions = filteredRegions.sort { region1, region2 in
				let region1Location = CLLocation(latitude: region1.center.latitude, longitude: region1.center.longitude)
				let region2Location = CLLocation(latitude: region2.center.latitude, longitude: region2.center.longitude)
				return fromLocation.distanceFromLocation(region1Location) < fromLocation.distanceFromLocation(region2Location)
			}
			return Array(sortedRegions[0..<min(number, sortedRegions.count)])
		} else {
			return Array(filteredRegions[0..<min(number, filteredRegions.count)])
		}
	}
	
	class func currentCapabilityStatusForService(kind: MMLocationServiceKind, usage: MMLocationServiceUsage) -> MMCapabilityStatus {
		guard CLLocationManager.locationServicesEnabled() && (!kind.contains(MMLocationServiceKind.RegionMonitoring) || CLLocationManager.isMonitoringAvailableForClass(CLCircularRegion)) else
		{
			return .NotAvailable
		}
		
		if (usage == .WhenInUse && !MMGeofencingService.isWhenInUseDescriptionProvided) || (usage == .Always && !MMGeofencingService.isAlwaysDescriptionProvided) {
			return .NotAvailable
		}
		
		switch CLLocationManager.authorizationStatus() {
		case .NotDetermined: return .NotDetermined
		case .Restricted: return .NotAvailable
		case .Denied: return .Denied
		case .AuthorizedAlways: return .Authorized
		case .AuthorizedWhenInUse:
			if usage == MMLocationServiceUsage.WhenInUse {
				return .Authorized
			} else {
				// the user wants .Always, but has .WhenInUse
				// return .NotDetermined so that we can prompt to upgrade the permission
				return .NotDetermined
			}
		}
	}
	
	private var previousLocation: CLLocation?
	let kRegionRefreshThreshold: CLLocationDistance = 200
	private func shouldRefreshRegionsWithNewLocation(location: CLLocation) -> Bool {
		guard let previousLocation = previousLocation else {
			return true
		}
		let monitorableRegionsCount = self.datasource.notExpiredRegions.count
		let distanceFromPreviousPoint = location.distanceFromLocation(previousLocation)
		MMLogDebug("[GeofencingService] distance from previous point = \(distanceFromPreviousPoint), monitorableRegionsCount = \(monitorableRegionsCount)")
		return distanceFromPreviousPoint > self.kRegionRefreshThreshold && monitorableRegionsCount > self.kMonitoringRegionsLimit
	}
	
	// MARK: - Location Manager delegate
	public func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
		assert(NSThread.isMainThread())
		MMLogDebug("[GeofencingService] locationManager did change the authorization status \(status.rawValue)")
		if let completion = self.completion where manager == self.locationManager && status != .NotDetermined {
			self.completion = nil
			
			switch status {
			case .AuthorizedAlways:
				completion(.Authorized)
			case .AuthorizedWhenInUse:
				completion(self.usageKind == .WhenInUse ? .Authorized : .Denied)
			case .Denied:
				completion(.Denied)
			case .Restricted:
				completion(.NotAvailable)
			case .NotDetermined:
				fatalError("Unreachable due to the if statement, but included to keep clang happy")
			}
		}
		
		if self.isRunning {
			switch status {
			case .AuthorizedWhenInUse, .Denied, .Restricted, .NotDetermined:
				stop()
			default:
				break
			}
		} else {
			switch status {
			case .AuthorizedAlways:
				startService()
			default:
				break
			}
		}
	}
	
	public func locationManager(manager: CLLocationManager, didEnterRegion region: CLRegion) {
		assert(NSThread.isMainThread())
		MMLogDebug("[GeofencingService] did enter circular region \(region)")
		if let datasourceRegion = datasource.regions[region.identifier] where datasourceRegion.isExpired == false {
			MMLogDebug("[GeofencingService] did enter datasource region \(datasourceRegion)")
			delegate?.didEnterRegion(datasourceRegion)
			NSNotificationCenter.mm_postNotificationFromMainThread(MMNotificationGeographicalRegionDidEnter, userInfo: [MMNotificationKeyGeographicalRegion: datasourceRegion])
		} else {
			MMLogDebug("[GeofencingService] region is expired.")
		}
	}
	
	public func locationManager(manager: CLLocationManager, didStartMonitoringForRegion region: CLRegion) {
		assert(NSThread.isMainThread())
		MMLogDebug("[GeofencingService] did start monitoring \(region)")
	}
	
	public func locationManager(manager: CLLocationManager, didExitRegion region: CLRegion) {
		assert(NSThread.isMainThread())
		MMLogDebug("[GeofencingService] did exit circular region \(region)")
		if let datasourceRegion = datasource.regions[region.identifier] where datasourceRegion.isExpired == false {
			MMLogDebug("[GeofencingService] did exit datasource region \(datasourceRegion)")
			delegate?.didExitRegion(datasourceRegion)
			NSNotificationCenter.mm_postNotificationFromMainThread(MMNotificationGeographicalRegionDidExit, userInfo: [MMNotificationKeyGeographicalRegion: datasourceRegion])
		} else {
			MMLogDebug("[GeofencingService] region is expired.")
		}
	}
	
	public func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
		assert(NSThread.isMainThread())
		MMLogDebug("[GeofencingService] did fail with error \(error)")
	}
	
	public func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		assert(NSThread.isMainThread())
		MMLogDebug("[GeofencingService] did update locations")
		guard let location = locations.last else {
			return
		}
		if self.shouldRefreshRegionsWithNewLocation(location) {
			self.previousLocation = location
			self.refreshMonitoredRegions()
		}
	}
}
