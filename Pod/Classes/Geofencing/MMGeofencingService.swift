//
//  MMGeofencingService.swift
//
//  Created by Ivan Cigic on 06/07/16.
//
//

import Foundation
import CoreLocation
import CoreData

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

public class MMGeofencingService: NSObject, MobileMessagingService {
	static let kDistanceFilter: CLLocationDistance = 100
    static let kRegionRefreshThreshold: CLLocationDistance = 200
	static let kMonitoringRegionsLimit: Int = 20
	static let kGeofencingPreferableUsage = MMLocationServiceUsage.Always
	static let kGeofencingMinimumAllowedUsage = MMLocationServiceUsage.WhenInUse
	static let kGeofencingSupportedAuthStatuses = [CLAuthorizationStatus.authorizedWhenInUse, CLAuthorizationStatus.authorizedAlways]

	var locationManager: CLLocationManager!
	var datasource: GeofencingDatasource!
	var isRunning = false
	let locationManagerQueue = MMQueue.Main.queue
	var mmContext: MobileMessaging!
	lazy var eventsHandlingQueue = MMOperationQueue.newSerialQueue
	
	// MARK: - Public
	
	/// Returns current user location with accuracy `kCLLocationAccuracyHundredMeters`.
	public var currentUserLocation: CLLocation? { return locationManager.location }
	public weak var delegate: MMGeofencingServiceDelegate?
	
	/// Returns all the regions available in the Geofencing Service storage.
	public var allRegions: Array<MMRegion> {
		var result = Array<MMRegion>()
		locationManagerQueue.executeSync() {
			result = self.datasource.allRegions
		}
		return result
	}
	
	/// Returns current capability status for Geofencing Service. For more information see `MMCapabilityStatus`.
	public class var currentCapabilityStatus: MMCapabilityStatus {
		return MMGeofencingService.currentCapabilityStatus(forService: MMLocationServiceKind.RegionMonitoring, usage: MMGeofencingService.kGeofencingMinimumAllowedUsage)
	}
	
	/// Requests permission to use location services whenever the app is running.
	/// - parameter usage: Defines the usage type for which permissions is requested.
	/// - parameter completion: A block that will be triggered once the authorization request is finished and the capability statys is defined. The current capability status is passed to the block as a parameter.
	public func authorize(usage: MMLocationServiceUsage, completion: @escaping (MMCapabilityStatus) -> Void) {
		authorizeService(kind: MMLocationServiceKind.RegionMonitoring, usage: usage, completion: completion)
	}
	
	/// Starts the Geofencing Service
	///
	/// During the startup process, the service automatically asks user to grant the appropriate permissions
	/// Once the user granted the permissions, the service succesfully lauches.
	/// - parameter completion: A block that will be triggered once the startup process is finished. Contains a Bool flag parameter, that indicates whether the startup succeded.
	public func start(_ completion: ((Bool) -> Void)? = nil) {
		MMLogDebug("[GeofencingService] starting ...")
		locationManagerQueue.executeAsync() {
			guard self.isRunning == false else
			{
				MMLogDebug("[GeofencingService] isRunning = \(self.isRunning))")
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
				self.authorizeService(kind: MMLocationServiceKind.RegionMonitoring, usage: MMGeofencingService.kGeofencingPreferableUsage) { capability in
					switch capability {
					case .Authorized:
						MMLogDebug("[GeofencingService] successfully authorized for `Always` mode")
						self.startService()
						completion?(true)
					default:
						MMLogDebug("[GeofencingService] was not authorized for `Always` mode. Canceling the startup.")
						completion?(false)
						break
					}
				}
			case .Denied, .NotAvailable:
				MMLogDebug("[GeofencingService] capability is \(currentCapability.rawValue). Canceling the startup.")
				completion?(false)
			}
		}
	}
	
	/// Stops the Geofencing Service
	public func stop(_ completion: ((Bool) -> Void)? = nil) {
		eventsHandlingQueue.cancelAllOperations()
		locationManagerQueue.executeAsync() {
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
			completion?(true)
		}
	}
	
	/// Accepts a geo message, which contains regions that should be monitored.
	/// - parameter message: A message object to add to the monitoring. Object of `MMGeoMessage` class.
	public func add(message: MMGeoMessage) {
		locationManagerQueue.executeAsync() {
			MMLogDebug("[GeofencingService] trying to add a message")
			guard self.isRunning == true else
			{
				MMLogDebug("[GeofencingService] isRunning = \(self.isRunning))")
				return
			}
			
			self.datasource.add(message: message)
			self.delegate?.didAddMessage(message: message)
			MMLogDebug("[GeofencingService] added a message\n\(message)")
			self.refreshMonitoredRegions(newRegions: message.regions)
		}
	}
	
	/// Removes a message from the monitoring.
	public func removeMessage(withId messageId: String) {
		locationManagerQueue.executeAsync() {
			self.datasource.removeMessage(withId: messageId)
			MMLogDebug("[GeofencingService] message removed \(messageId)")
			self.refreshMonitoredRegions()
		}
	}
	
	/// The geo event handling object defines the behaviour that is triggered during the geo event.
	///
	/// You can implement your own geo event handling either by subclassing `MMDefaultGeoEventHandling` or implementing the `GeoEventHandling` protocol.
	public static var geoEventsHandler: GeoEventHandling?
	
	// MARK: - Internal
	//FIXME: use background queue. (initialize separate NSThread which lives as long as geo service running)
	init (storage: MMCoreDataStorage, mmContext: MobileMessaging) {
		super.init()
		locationManagerQueue.executeSync() {
			self.locationManager = CLLocationManager()
			self.locationManager.delegate = self
			self.locationManager.distanceFilter = MMGeofencingService.kDistanceFilter
			self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
			self.datasource = GeofencingDatasource(storage: storage)
			self.mmContext = mmContext
			self.previousLocation = MobileMessaging.currentInstallation?.location
		}
	}
	
	deinit {
		eventsHandlingQueue.cancelAllOperations()
	}
	
	class var isDescriptionProvidedForWhenInUseUsage: Bool {
		return Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") != nil
	}
	
	class var isDescriptionProvidedForAlwaysUsage: Bool {
		return Bundle.main.object(forInfoDictionaryKey: "NSLocationAlwaysUsageDescription") != nil
	}
	
	func authorizeService(kind: MMLocationServiceKind, usage: MMLocationServiceUsage, completion: @escaping (MMCapabilityStatus) -> Void) {
		locationManagerQueue.executeAsync() {
			guard self.capabilityCompletion == nil else
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
			
			self.capabilityCompletion = completion
			self.desirableUsageKind = usage
			
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
	
	func regionsToStopMonitoring(monitoredRegions: Set<CLCircularRegion>) -> Set<CLCircularRegion> {
		assert(Thread.isMainThread)
		let regionsWeAreInside: Set<CLCircularRegion> = Set(monitoredRegions.filter {
			guard let currentCoordinate = self.locationManager.location?.coordinate else
            {
				return false
			}
			return $0.contains(currentCoordinate)
        })
		
		let deadRegions: Set<CLCircularRegion> = Set(monitoredRegions.filter {
			self.dataSourceRegions(from: [$0]).contains(where: { $0.message?.isNotExpired ?? false}) == false
        })
		return monitoredRegions.subtracting(regionsWeAreInside).union(deadRegions)
	}
	
	func regionsToStartMonitoring(monitoredRegions: Set<CLCircularRegion>) -> Set<CLCircularRegion> {
		assert(Thread.isMainThread)
		let notExpiredRegions = Set(self.datasource.liveRegions.map { $0.circularRegion })
		let number = MMGeofencingService.kMonitoringRegionsLimit - monitoredRegions.count
		let location = self.locationManager.location ?? previousLocation
		let array = MMGeofencingService.closestLiveRegions(withNumberLimit: number, forLocation: location, fromRegions: notExpiredRegions, filter: { monitoredRegions.contains($0) == false })
		return Set(array)
	}
	
	class func closestLiveRegions(withNumberLimit number: Int, forLocation: CLLocation?, fromRegions regions: Set<CLCircularRegion>, filter: ((CLCircularRegion) -> Bool)?) -> [CLCircularRegion] {
		
		let number = Int(max(0, number))
		guard number > 0 else
		{
			return []
		}
		
		let filterPredicate: (CLCircularRegion) -> Bool = filter == nil ? { (_: CLCircularRegion) -> Bool in return true } : filter!
		let filteredRegions: [CLCircularRegion] = Array(regions).filter(filterPredicate)
		
		if let location = forLocation {
			let sortedRegions = filteredRegions.sorted { region1, region2 in
				let region1Location = CLLocation(latitude: region1.center.latitude, longitude: region1.center.longitude)
				let region2Location = CLLocation(latitude: region2.center.latitude, longitude: region2.center.longitude)
				return location.distance(from: region1Location) < location.distance(from: region2Location)
			}
			return Array(sortedRegions[0..<min(number, sortedRegions.count)])
		} else {
			return Array(filteredRegions[0..<min(number, filteredRegions.count)])
		}
	}
	
	class func currentCapabilityStatus(forService kind: MMLocationServiceKind, usage: MMLocationServiceUsage) -> MMCapabilityStatus {
		guard CLLocationManager.locationServicesEnabled() && (!kind.contains(options: MMLocationServiceKind.RegionMonitoring) || CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self)) else
		{
			return .NotAvailable
		}
		
		if (usage == .WhenInUse && !MMGeofencingService.isDescriptionProvidedForWhenInUseUsage) || (usage == .Always && !MMGeofencingService.isDescriptionProvidedForAlwaysUsage) {
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
	
	// MARK: - Private
	fileprivate var desirableUsageKind = MMLocationServiceUsage.WhenInUse
	
	fileprivate var capabilityCompletion: ((MMCapabilityStatus) -> Void)?
	
	fileprivate func restartLocationManager() {
		if mmContext.application.applicationState == UIApplicationState.active {
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
	
	fileprivate func startService() {
		locationManagerQueue.executeAsync() {
			guard self.isRunning == false else
			{
				return
			}
			
			self.restartLocationManager()
			self.refreshMonitoredRegions()
			
			NotificationCenter.mm_postNotificationFromMainThread(name: MMNotificationGeoServiceDidStart, userInfo: nil)
			
			NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationDidFinishLaunching, object: nil, queue: nil, using:
				{ [weak self] notification in
					assert(Thread .isMainThread)
					if notification.userInfo?[UIApplicationLaunchOptionsKey.location] != nil {
						MMLogDebug("[GeofencingService] The app relaunched by the OS.")
						self?.restartLocationManager()
					}
				}
			)
			
			NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationDidEnterBackground, object: nil, queue: nil, using:
				{ [weak self] notification in
					MMLogDebug("[GeofencingService] App did enter background.")
					assert(Thread .isMainThread)
					self?.restartLocationManager()
					if let previousLocation = self?.previousLocation {
						MobileMessaging.currentInstallation?.location = previousLocation
					}
				}
			)
			
			NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationDidBecomeActive, object: nil, queue: nil, using:
				{ [weak self] note in
					MMLogDebug("[GeofencingService] App did become active.")
					assert(Thread .isMainThread)
					self?.restartLocationManager()
				}
			)
			
			self.isRunning = true
			MMLogDebug("[GeofencingService] started.")
		}
	}
	
	fileprivate func stopMonitoringMonitoredRegions() {
		locationManagerQueue.executeAsync() {
			MMLogDebug("[GeofencingService] stopping monitoring all regions")
			for monitoredRegion in self.locationManager.monitoredRegions {
				self.locationManager.stopMonitoring(for: monitoredRegion)
			}
		}
	}
	
	fileprivate func dataSourceRegions(from circularRegions: Set<CLCircularRegion>) -> [MMRegion] {
		return circularRegions.reduce([MMRegion]()) { (result, region) -> [MMRegion] in
			return self.datasource.regionsDictionary.filter{ (key, value) -> Bool in
				return key.hasSuffix("_\(region.identifier)")
				}.map{$0.1}
		}
	}
	
	fileprivate func refreshMonitoredRegions(newRegions: Set<MMRegion>? = nil) {
		locationManagerQueue.executeAsync() {
			
			var monitoredRegions: Set<CLCircularRegion> = Set(self.locationManager.monitoredRegions.flatMap { $0 as? CLCircularRegion })
			MMLogDebug("[GeofencingService] refreshing monitored regions: \n\(monitoredRegions) \n datasource regions: \n \(self.datasource.regionsDictionary)")
			
			//check what to stop
			let regionsToStopMonitoring = self.regionsToStopMonitoring(monitoredRegions: monitoredRegions)
			MMLogDebug("[GeofencingService] will stop monitoring regions: \n\(self.dataSourceRegions(from: regionsToStopMonitoring))")
			regionsToStopMonitoring.forEach{self.locationManager.stopMonitoring(for: $0)}
			monitoredRegions.subtract(regionsToStopMonitoring)
			
			//check what to start
			let regionsToStartMonitoring = self.regionsToStartMonitoring(monitoredRegions: monitoredRegions)
			MMLogDebug("[GeofencingService] will start monitoring regions: \n\(self.dataSourceRegions(from: regionsToStartMonitoring))")
			regionsToStartMonitoring.forEach({ (region) in
				region.notifyOnEntry = true
				region.notifyOnExit = true
				self.locationManager.startMonitoring(for: region)
			})
			monitoredRegions.formUnion(regionsToStartMonitoring)
			
			//try to enter, if we are already inside added region
			guard let newRegions = newRegions else {
				return
			}
			let monitoredDatasourceRegions = Set(self.dataSourceRegions(from: monitoredRegions))
			let intersection = monitoredDatasourceRegions.filter({ (region) -> Bool in
				return newRegions.contains(where: {$0.dataSourceIdentifier == region.dataSourceIdentifier})
			})
			
			intersection.forEach({ (region) in
				if let currentCoordinate = self.locationManager.location?.coordinate , region.circularRegion.contains(currentCoordinate) {
					if region.message?.isNowAppropriateTimeForEntryNotification ?? false {
						MMLogDebug("[GeofencingService] already inside new region: \(region)")
						self.onEnter(datasourceRegion: region)
					}
				}
			})
		}
	}
	
	fileprivate var previousLocation: CLLocation?
}


extension MMGeofencingService {
	@nonobjc static var currentDate: Date? // @nonobjc is to shut up the "A declaration cannot be both 'final' and 'dynamic'" error
	
	static func isGeoCampaignNotExpired(campaign: MMGeoMessage) -> Bool {
		let now = MMGeofencingService.currentDate ?? MobileMessaging.date.now
		return campaign.campaignState == .Active && now.compare(campaign.expiryTime) == .orderedAscending && now.compare(campaign.startTime) != .orderedAscending
	}
	
	static func isNowAppropriateDay(forDeliveryTime dt: DeliveryTime) -> Bool {
		guard let days = dt.days, !days.isEmpty else {
			return true
		}
		let now = MMGeofencingService.currentDate ?? MobileMessaging.date.now
		let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
		let comps = calendar.dateComponents(Set([Calendar.Component.weekday]), from: now)
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
	
	static func isNowAppropriateTime(forDeliveryTimeInterval dti: DeliveryTimeInterval) -> Bool {
		let now = MMGeofencingService.currentDate ?? MobileMessaging.date.now
		return DeliveryTimeInterval.isTime(now, between: dti.fromTime, and: dti.toTime)
	}
	
	static func isValidRegionEvent(_ regionEvent: RegionEvent) -> Bool {
		if regionEvent.limit != 0 && regionEvent.occuringCounter >= regionEvent.limit {
			return false
		}
		let now = MMGeofencingService.currentDate ?? MobileMessaging.date.now
		return regionEvent.lastOccuring?.addingTimeInterval(TimeInterval(regionEvent.timeout * 60)).compare(now) != .orderedDescending
	}
}

extension MMGeofencingService: CLLocationManagerDelegate {
	public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
		assert(Thread.isMainThread)
		MMLogDebug("[GeofencingService] locationManager did change the authorization status \(status.rawValue)")
		if let completion = self.capabilityCompletion , manager == self.locationManager && status != .notDetermined {
			self.capabilityCompletion = nil
			
			switch status {
			case .authorizedAlways:
				completion(.Authorized)
			case .authorizedWhenInUse:
				completion(self.desirableUsageKind == MMLocationServiceUsage.WhenInUse ? .Authorized : .Denied)
			case .denied:
				completion(.Denied)
			case .restricted:
				completion(.NotAvailable)
			case .notDetermined:
				fatalError("Unreachable due to the if statement, but included to keep clang happy")
			}
		}
		
		switch (self.isRunning, status) {
		case (true, let status) where !MMGeofencingService.kGeofencingSupportedAuthStatuses.contains(status):
			stop()
		case (false, let status) where MMGeofencingService.kGeofencingSupportedAuthStatuses.contains(status):
			startService()
		default:
			break
		}
	}
	
	public func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
		assert(Thread.isMainThread)
		MMLogDebug("[GeofencingService] did start monitoring for region: \(region)")
	}
	
	public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
		assert(Thread.isMainThread)
		MMLogDebug("[GeofencingService] will enter region \(region)")
		datasource.validRegionsForEntryEvent(with: region.identifier)?.forEach { datasourceRegion in
			onEnter(datasourceRegion: datasourceRegion)
		}
	}
	
	public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
		assert(Thread.isMainThread)
		MMLogDebug("[GeofencingService] did fail with error \(error)")
	}
	
	public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		assert(Thread.isMainThread)
		MMLogDebug("[GeofencingService] did update locations")
		guard let location = locations.last else
        {
			return
		}
		if self.shouldRefreshRegionsWithNewLocation(location: location) {
			self.previousLocation = location
			self.refreshMonitoredRegions()
		}
	}
	
    private func shouldRefreshRegionsWithNewLocation(location: CLLocation) -> Bool {
        assert(Thread.isMainThread)
        guard let previousLocation = previousLocation else
        {
            return true
        }
        let monitorableRegionsCount = self.datasource.liveRegions.count
        let distanceFromPreviousPoint = location.distance(from: previousLocation)
        MMLogDebug("[GeofencingService] distance from previous point = \(distanceFromPreviousPoint), monitorableRegionsCount = \(monitorableRegionsCount)")
        return distanceFromPreviousPoint > MMGeofencingService.kRegionRefreshThreshold && monitorableRegionsCount > MMGeofencingService.kMonitoringRegionsLimit
    }
}


extension MMGeofencingService {
	
	func onEnter(datasourceRegion: MMRegion) {
		assert(Thread.isMainThread)
		guard let message = datasourceRegion.message else {
			return
		}
		
		report(on: .entry, forRegionId: datasourceRegion.identifier, geoMessage: message, completion: { campaignState in
			MMLogDebug("[GeofencingService] did enter region \(datasourceRegion), campaign state: \(campaignState.rawValue)")
			if campaignState == .Active {
				self.didEnterActiveCampaignRegion(datasourceRegion)
			}
		})
	}
	
	func report(on eventType: RegionEventType, forRegionId regionId: String, geoMessage: MMGeoMessage, completion: ((CampaignState) -> Void)?) {
		
		eventsHandlingQueue.addOperation {
			let ctx = self.datasource.context
			ctx.performAndWait {
				GeoEventReportObject.createEntity(withCampaignId: geoMessage.campaignId, eventType: eventType.rawValue, regionId: regionId, messageId: geoMessage.messageId, in: ctx)
			}
			ctx.MM_saveToPersistentStoreAndWait()
		}
		
        reportOnEvents { eventsReportingResponse in

            self.refreshDatasource()
            
			let campaignState: CampaignState
			if let scIds = eventsReportingResponse?.suspendedCampaignIds, scIds.contains(geoMessage.campaignId) {
				campaignState = .Suspended
			} else if let fcIds = eventsReportingResponse?.finishedCampaignIds, fcIds.contains(geoMessage.campaignId) {
				campaignState = .Finished
			} else {
				campaignState = .Active
			}
			
			completion?(campaignState)
		}
	}
	
	private func didEnterActiveCampaignRegion(_ datasourceRegion: MMRegion) {
		delegate?.didEnterRegion(region: datasourceRegion)
		
		MMGeofencingService.geoEventsHandler?.didEnter(region: datasourceRegion)
		
		NotificationCenter.mm_postNotificationFromMainThread(name: MMNotificationGeographicalRegionDidEnter, userInfo: [MMNotificationKeyGeographicalRegion: datasourceRegion])
	}
	
	private func reportOnEvents(completion: ((GeoEventReportingResponse?) -> ())?) {
		// we don't consider isRunning status here on purpose
		eventsHandlingQueue.addOperation(GeoEventReportingOperation(context: self.datasource.context, mmContext: mmContext, finishBlock: { result in
			completion?(result.value)
		}))
	}
	
    private func refreshDatasource() {
        datasource.reload()
    }
	
	func syncWithServer(completion: ((GeoEventReportingResponse?) -> ())? = nil) {
		reportOnEvents(completion: completion)
	}
}

@objc public protocol GeoEventHandling {
    /// This callback is triggered after the geo event occurs. Default behaviour is implemented by `MMDefaultGeoEventHandling` class.
    func didEnter(region: MMRegion)
}
