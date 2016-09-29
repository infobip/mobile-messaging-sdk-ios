//
//  MMGeofencingService.swift
//
//  Created by Ivan Cigic on 06/07/16.
//
//

import Foundation
import CoreLocation
import UIKit

/// Describes the kind of location service. Possible values:
/// - Location Updates
/// - Region Monitoring
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

/// Describes the usage type for the location service. Possible values:
/// - When in Use
/// - Always
@objc public enum MMLocationServiceUsage: Int {
	/// This app is authorized to start most location services while running in the foreground.
	case WhenInUse
	/// This app is authorized to start location services at any time.
	case Always
}

/// Describes the capability status for Geofencing Service. Possible values:
/// - `notDetermined`: The capability has not been requested yet
/// - `authorized`: The capability has been requested and approved
/// - `denied`: The capability has been requested but was denied by the user
/// - `notAvailable`: The capability is not available (perhaps due to restrictions, or lack of support)
@objc public enum MMCapabilityStatus: Int {
	case NotDetermined
	case Authorized
	case Denied
	case NotAvailable
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

public class MMGeofencingService: NSObject, CLLocationManagerDelegate {
	let kDistanceFilter: CLLocationDistance = 100
	let kMonitoringRegionsLimit: Int = 20
	var isAvailable: Bool {
		return MMGeofencingService.currentCapabilityStatus == .Authorized && MMGeofencingService.geoServiceEnabled
	}
	
	class func withStorage(storage: MMCoreDataStorage) -> MMGeofencingService {
		sharedInstance = MMGeofencingService(storage: storage)
		return sharedInstance!
	}
	
	static var sharedInstance: MMGeofencingService?
	var locationManager: CLLocationManager!
	var datasource: MMGeofencingDatasource!
	var isRunning = false
	
	// MARK: - Public
	static var _geoServiceEnabled = true
	public static var geoServiceEnabled: Bool {
		set {
			if newValue != geoServiceEnabled && newValue == false {
				MMGeofencingService.sharedInstance?.stop()
			}
			_geoServiceEnabled = newValue
		}
		get {
			return _geoServiceEnabled
		}
	}
	
	/// Returns current user location with accuracy `kCLLocationAccuracyHundredMeters`.
	public var currentUserLocation: CLLocation? { return locationManager.location }
	public weak var delegate: MMGeofencingServiceDelegate?
	
	/// Returns all the geo messages available in the Geofencing Service storage.
	public var allMessages: Set<MMGeoMessage> { return datasource.messages }
	
	/// Returns all the regions available in the Geofencing Service storage.
	public var allRegions: Set<MMRegion> { return Set(datasource.regionsDictionary.values) }
	
	/// Returns current capability status for Geofencing Service. For more information see `MMCapabilityStatus`.
	public class var currentCapabilityStatus: MMCapabilityStatus {
		return MMGeofencingService.currentCapabilityStatus(forService: MMLocationServiceKind.RegionMonitoring, usage: .Always)
	}

	/// Requests permission to use location services whenever the app is running.
	/// - parameter usage: Defines the usage type for which permissions is requested.
	/// - parameter completion: A block that will be triggered once the authorization request is finished and the capability statys is defined. The current capability status is passed to the block as a parameter.
	public func authorize(usage: MMLocationServiceUsage, completion: MMCapabilityStatus -> Void) {
		authorizeService(MMLocationServiceKind.RegionMonitoring, usage: usage, completion: completion)
	}

	/// Starts the Geofencing Service
	///
	/// During the startup process, the service automatically asks user to grant the appropriate permissions
	/// Once the user granted the permissions, the service succesfully lauches.
	/// - parameter completion: A block that will be triggered once the startup process is finished. Contains a Bool flag parameter, that indicates whether the startup succeded.
	public func start(completion: (Bool -> Void)? = nil) {
		MMLogDebug("[GeofencingService] starting ...")
		guard MMGeofencingService.geoServiceEnabled == true else {
			completion?(false)
			MMLogDebug("[GeofencingService] startup cancelled. Service is disabled.")
			return
		}
		serviceQueue.executeAsync() {
			guard self.isRunning == false else
			{
				MMLogDebug("[GeofencingService] locationManagerEnabled = \(MMGeofencingService.geoServiceEnabled), isRunning = \(self.isRunning))")
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
	
	/// Stops the Geofencing Service
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
	
	/// Accepts a geo message, which contains regions that should be monitored.
	/// - parameter message: A message object to add to the monitoring. Object of `MMGeoMessage` class.
	public func add(message message: MMGeoMessage) {
		serviceQueue.executeAsync() {
			MMLogDebug("[GeofencingService] trying to add a message")
			guard MMGeofencingService.geoServiceEnabled == true && self.isRunning == true else
			{
				MMLogDebug("[GeofencingService] geoServiceEnabled = \(MMGeofencingService.geoServiceEnabled), isRunning = \(self.isRunning))")
				return
			}
			
			self.datasource.add(message: message)
			self.delegate?.didAddMessage(message)
			MMLogDebug("[GeofencingService] added a message\n\(message)")
			self.refreshMonitoredRegions()
		}
	}

	/// Removes a message from the monitoring.
	public func removeMessage(withId messageId: String) {
		serviceQueue.executeAsync() {
			self.datasource.removeMessage(withId: messageId)
			MMLogDebug("[GeofencingService] message removed \(messageId)")
			self.refreshMonitoredRegions()
		}
	}
	
	/// The geo event handling object defines the behaviour that is triggered during the geo event.
	///
	/// You can implement your own geo event handling either by subclassing `MMDefaultGeoEventHandling` or implementing the `GeoEventHandling` protocol.
	public static var geoEventsHandler: GeoEventHandling? = MMDefaultGeoEventHandling()
	
// MARK: - Internal
	let serviceQueue = MMQueue.Main.queue
	
	init (storage: MMCoreDataStorage) {
		super.init()
		serviceQueue.executeSync() {
			self.locationManager = CLLocationManager()
			self.locationManager.delegate = self
			self.locationManager.distanceFilter = self.kDistanceFilter
			self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
			self.datasource = MMGeofencingDatasource(storage: storage)
			self.previousLocation = MobileMessaging.currentInstallation?.location
		}
	}
	
	class var isDescriptionProvidedForWhenInUseUsage: Bool {
		return NSBundle.mainBundle().objectForInfoDictionaryKey("NSLocationWhenInUseUsageDescription") != nil
	}
	
	class var isDescriptionProvidedForAlwaysUsage: Bool {
		return NSBundle.mainBundle().objectForInfoDictionaryKey("NSLocationAlwaysUsageDescription") != nil
	}
	
	func authorizeService(kind: MMLocationServiceKind, usage: MMLocationServiceUsage, completion: MMCapabilityStatus -> Void) {
		serviceQueue.executeAsync() {
			guard self.capabilityCompletion == nil else
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
			
			self.capabilityCompletion = completion
			self.usageKind = usage
		
			switch usage {
			case .WhenInUse:
				MMLogDebug("[GeofencingService] requesting 'WhenInUse'")
				
				if !MMGeofencingService.isDescriptionProvidedForWhenInUseUsage {
					MMLogDebug("[GeofencingService] NSLocationWhenInUseUsageDescription is not defined. Geo service cannot be used")
					completion(.NotAvailable)
				} else {
					self.locationManager.requestWhenInUseAuthorization()
				}
			case .Always:
				MMLogDebug("[GeofencingService] requesting 'Always'")
				
				if !MMGeofencingService.isDescriptionProvidedForAlwaysUsage {
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
	
	private var capabilityCompletion: (MMCapabilityStatus -> Void)?
	
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
			guard MMGeofencingService.geoServiceEnabled == true && self.isRunning == false else
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
					if let previousLocation = self?.previousLocation {
						MobileMessaging.currentInstallation?.location = previousLocation
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
			
			let closestLiveRegions = self.closestLiveRegions
			MMLogDebug("[GeofencingService] datasource regions: \n\(self.datasource.regionsDictionary.values)")

			let currentlyMonitoredRegions: Set<CLCircularRegion> = Set(self.locationManager.monitoredRegions.flatMap {$0 as? CLCircularRegion})
			MMLogDebug("[GeofencingService] currently monitored regions \n\(currentlyMonitoredRegions.flatMap { return self.datasource.regionsDictionary[$0.identifier] })")
			
			let regionsWeAreInside: Set<CLCircularRegion> = Set(currentlyMonitoredRegions.filter {
					if let currentCoordinate = self.locationManager.location?.coordinate {
						return $0.containsCoordinate(currentCoordinate)
					} else {
						return false
					}
				}
			)
			MMLogDebug("[GeofencingService] regions we are inside: \n\(regionsWeAreInside.flatMap { return self.datasource.regionsDictionary[$0.identifier] })")
			
			let deadRegions: Set<CLCircularRegion> = Set(currentlyMonitoredRegions.filter {
					return self.datasource.regionsDictionary[$0.identifier]?.isLive == false ?? true
				}
			)
			MMLogDebug("[GeofencingService] dead monitored regions: \n\(deadRegions.flatMap { return self.datasource.regionsDictionary[$0.identifier] })")
			
			let regionsToStopMonitoring = currentlyMonitoredRegions.subtract(regionsWeAreInside).union(deadRegions)
			MMLogDebug("[GeofencingService] regions to stop monitoring: \n\(regionsToStopMonitoring.flatMap { return self.datasource.regionsDictionary[$0.identifier] })")
			
			for region in regionsToStopMonitoring {
				self.locationManager.stopMonitoringForRegion(region)
			}
			
			MMLogDebug("[GeofencingService] regions to start monitoring: \n\(closestLiveRegions.flatMap { return self.datasource.regionsDictionary[$0.identifier] })")

			for region in closestLiveRegions {
				region.notifyOnEntry = true
				region.notifyOnExit = true
				self.locationManager.startMonitoringForRegion(region)
				
				//check if aleady in region
				if let currentCoordinate = self.locationManager.location?.coordinate where region.containsCoordinate(currentCoordinate) {
					MMLogDebug("[GeofencingService] detected a region in which we currently are \(self.datasource.regionsDictionary[region.identifier])")
					self.locationManager(self.locationManager, didEnterRegion: region)
				}
			}
		}
	}
	
	var closestLiveRegions: Set<CLCircularRegion> {
		let notExpiredRegions = Set(self.datasource.liveRegions.flatMap { $0.circularRegion })
		let number = self.kMonitoringRegionsLimit - self.locationManager.monitoredRegions.count
		let location = self.locationManager.location ?? previousLocation
		let array = MMGeofencingService.closestLiveRegions(withNumberLimit: number, forLocation: location, fromRegions: notExpiredRegions, filter: { self.locationManager.monitoredRegions.contains($0) == false })
		return Set(array)
	}
	
	class func closestLiveRegions(withNumberLimit number: Int, forLocation: CLLocation?, fromRegions regions: Set<CLCircularRegion>, filter: (CLCircularRegion -> Bool)?) -> [CLCircularRegion] {
		
		let number = Int(max(0, number))
		guard number > 0 else
		{
			return []
		}
		
		let filterPredicate: CLCircularRegion -> Bool = filter == nil ? { (_: CLCircularRegion) -> Bool in return true } : filter!
		let filteredRegions: [CLCircularRegion] = Array(regions).filter(filterPredicate)
		
		if let location = forLocation {
			let sortedRegions = filteredRegions.sort { region1, region2 in
				let region1Location = CLLocation(latitude: region1.center.latitude, longitude: region1.center.longitude)
				let region2Location = CLLocation(latitude: region2.center.latitude, longitude: region2.center.longitude)
				return location.distanceFromLocation(region1Location) < location.distanceFromLocation(region2Location)
			}
			return Array(sortedRegions[0..<min(number, sortedRegions.count)])
		} else {
			return Array(filteredRegions[0..<min(number, filteredRegions.count)])
		}
	}
	
	class func currentCapabilityStatus(forService kind: MMLocationServiceKind, usage: MMLocationServiceUsage) -> MMCapabilityStatus {
		guard CLLocationManager.locationServicesEnabled() && (!kind.contains(MMLocationServiceKind.RegionMonitoring) || CLLocationManager.isMonitoringAvailableForClass(CLCircularRegion)) else
		{
			return .NotAvailable
		}
		
		if (usage == .WhenInUse && !MMGeofencingService.isDescriptionProvidedForWhenInUseUsage) || (usage == .Always && !MMGeofencingService.isDescriptionProvidedForAlwaysUsage) {
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
		let monitorableRegionsCount = self.datasource.liveRegions.count
		let distanceFromPreviousPoint = location.distanceFromLocation(previousLocation)
		MMLogDebug("[GeofencingService] distance from previous point = \(distanceFromPreviousPoint), monitorableRegionsCount = \(monitorableRegionsCount)")
		return distanceFromPreviousPoint > self.kRegionRefreshThreshold && monitorableRegionsCount > self.kMonitoringRegionsLimit
	}
	
// MARK: - Location Manager delegate
	public func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
		assert(NSThread.isMainThread())
		MMLogDebug("[GeofencingService] locationManager did change the authorization status \(status.rawValue)")
		if let completion = self.capabilityCompletion where manager == self.locationManager && status != .NotDetermined {
			self.capabilityCompletion = nil
			
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
		datasource.regions(withIdentifier: region.identifier)?.forEach({ (datasourceRegion) in
			if datasourceRegion.isLive(for: .entry) {
				datasource.triggerEvent(for: .entry, region: datasourceRegion)
				MMLogDebug("[GeofencingService] did enter datasource region \(datasourceRegion)")
				delegate?.didEnterRegion(datasourceRegion)
				MMGeofencingService.geoEventsHandler?.didReceiveGeoEvent(datasourceRegion)
				NSNotificationCenter.mm_postNotificationFromMainThread(MMNotificationGeographicalRegionDidEnter, userInfo: [MMNotificationKeyGeographicalRegion: datasourceRegion])
			} else {
				MMLogDebug("[GeofencingService] region is expired.")
			}
		})
	}
	
	public func locationManager(manager: CLLocationManager, didStartMonitoringForRegion region: CLRegion) {
		assert(NSThread.isMainThread())
		MMLogDebug("[GeofencingService] did start monitoring \(region)")
	}
	
	public func locationManager(manager: CLLocationManager, didExitRegion region: CLRegion) {
		assert(NSThread.isMainThread())
		MMLogDebug("[GeofencingService] did exit circular region \(region)")
		datasource.regions(withIdentifier: region.identifier)?.forEach({ (datasourceRegion) in
			if datasourceRegion.isLive(for: .exit) {
				datasource.triggerEvent(for: .exit, region: datasourceRegion)
				MMLogDebug("[GeofencingService] did exit datasource region \(datasourceRegion)")
				delegate?.didExitRegion(datasourceRegion)
				MMGeofencingService.geoEventsHandler?.didReceiveGeoEvent(datasourceRegion)
				NSNotificationCenter.mm_postNotificationFromMainThread(MMNotificationGeographicalRegionDidExit, userInfo: [MMNotificationKeyGeographicalRegion: datasourceRegion])
			} else {
				MMLogDebug("[GeofencingService] region is expired.")
			}
		})
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

@objc public protocol GeoEventHandling {
	/// This callback is triggered after the geo event occurs. Default behaviour is implemented by `MMDefaultGeoEventHandling` class.
	func didReceiveGeoEvent(region: MMRegion)
}

public class MMDefaultGeoEventHandling: GeoEventHandling {
	@objc public func didReceiveGeoEvent(region: MMRegion) {
		if let message = region.message {
			self.presentLocalNotificationAlert(with: message)
		}
	}
	
	func presentLocalNotificationAlert(with message: MMMessage) {
		MMLocalNotification.presentLocalNotification(with: message)
	}
}
