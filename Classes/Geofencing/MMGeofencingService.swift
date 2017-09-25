//
//  MMGeofencingService.swift
//
//  Created by Ivan Cigic on 06/07/16.
//
//

import CoreLocation

extension MobileMessaging {
	/// This service manages geofencing areas, emits geografical regions entering/exiting notifications.
	///
	/// You access the Geofencing service APIs through this property.
	public class var geofencingService: GeofencingService? {
		if GeofencingService.sharedInstance == nil {
			guard let defaultContext = MobileMessaging.sharedInstance else {
				return nil
			}
			GeofencingService.sharedInstance = GeofencingService(mmContext: defaultContext)
		}
		return GeofencingService.sharedInstance
	}
	
	/// Fabric method for Mobile Messaging session.
	/// Use this method to enable the Geofencing service.
	public func withGeofencingService() -> MobileMessaging {
		GeofencingService.isGeoServiceNeedsToStart = true
		if GeofencingService.sharedInstance == nil {
			GeofencingService.sharedInstance = GeofencingService(mmContext: self)
		}
		return self
	}
}

public class GeofencingService: NSObject, MobileMessagingService {
	
	var uniqueIdentifier: String {
		return "com.mobile-messaging.subservice.GeofencingService"
	}
	
	public func syncWithServer(_ completion: ((NSError?) -> Void)?) {
		syncWithServer(completion: { (result) in
			completion?(result?.error)
		})
	}
	
	func mobileMessagingDidStart(_ mmContext: MobileMessaging) {
		guard GeofencingService.isGeoServiceNeedsToStart && mmContext.isPushRegistrationEnabled else {
			return
		}
		GeofencingService.isGeoServiceNeedsToStart = false
		start(nil)
	}

	func mobileMessagingDidStop(_ mmContext: MobileMessaging) {
		stop()
		GeofencingService.sharedInstance = nil
	}

	func pushRegistrationStatusDidChange(_ mmContext: MobileMessaging) {
		if mmContext.isPushRegistrationEnabled == true {
			start(nil)
		} else {
			stop(nil)
		}
	}
	
	func populateNewPersistedMessage(_ message: inout MessageManagedObject, originalMessage: MTMessage) -> Bool {
		guard let geoSignalingMessage = MMGeoMessage(payload: originalMessage.originalPayload) else {
			MMLogDebug("[GeofencingService] cannot populate message \(message.messageId)")
			return false
		}
		
		//this code must perform only for geo signaling messages
		message.creationDate = Date(timeIntervalSince1970: originalMessage.sendDateTime)
		message.messageId = originalMessage.messageId
		message.reportSent = originalMessage.isDeliveryReportSent
		message.payload = geoSignalingMessage.originalPayload
		message.messageType = .Geo
		message.isSilent = originalMessage.isSilent
		message.campaignState = .Active
		message.campaignId = geoSignalingMessage.campaignId
		MMLogDebug("[GeofencingService] attributes fulfilled for message \(message.messageId)")
		return true
	}
	
	func handleNewMessage(_ message: MTMessage, completion: ((MessageHandlingResult) -> Void)?) {
		guard let geoSignalingMessage = MMGeoMessage(payload: message.originalPayload) else {
			completion?(.noData)
			return
		}
		add(message: geoSignalingMessage) {
			completion?(.noData)
		}
	}
	
	private var _isRunning: Bool = false
	var isRunning: Bool  {
		get {
			var ret: Bool = false
			locationManagerQueue.executeSync() {
				ret = self._isRunning
			}
			return ret
		}
		set {
			locationManagerQueue.executeAsync() {
				self._isRunning = newValue
			}
		}
	}
	
	var systemData: [String: AnyHashable]? {
		return [SystemDataKeys.geofencingServiceEnabled: type(of: self).isGeofencingServiceEnabled]
	}

	public static var isGeofencingServiceEnabled: Bool {
		return currentCapabilityStatus == GeofencingCapabilityStatus.authorized
	}
	
	static var isGeoServiceNeedsToStart: Bool = false
	static var sharedInstance: GeofencingService?
	var geofencingServiceQueue: RemoteAPIQueue!
	var locationManager: CLLocationManager!
	var datasource: GeofencingDatasource!
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
	public class var currentCapabilityStatus: GeofencingCapabilityStatus {
		return GeofencingService.currentCapabilityStatus(forService: LocationServiceKind.regionMonitoring, usage: GeofencingConstants.minimumAllowedUsage)
	}
	
	/// Requests permission to use location services whenever the app is running.
	/// - parameter usage: Defines the usage type for which permissions is requested.
	/// - parameter completion: A block that will be triggered once the authorization request is finished and the capability statys is defined. The current capability status is passed to the block as a parameter.
	public func authorize(usage: LocationServiceUsage, completion: @escaping (GeofencingCapabilityStatus) -> Void) {
		authorizeService(kind: LocationServiceKind.regionMonitoring, usage: usage, completion: completion)
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
				MMLogDebug("[GeofencingService] isRunning = \(self.isRunning). Cancelling...")
				completion?(false)
				return
			}
			
			let currentCapability = type(of: self).currentCapabilityStatus
			switch currentCapability {
			case .authorized:
				self.startService()
				completion?(true)
			case .notDetermined:
				MMLogDebug("[GeofencingService] capability is 'not determined', authorizing...")
				self.authorizeService(kind: LocationServiceKind.regionMonitoring, usage: GeofencingConstants.preferableUsage) { capability in
					switch capability {
					case .authorized:
						MMLogDebug("[GeofencingService] successfully authorized for `Always` mode")
						self.startService()
						completion?(true)
					default:
						MMLogDebug("[GeofencingService] was not authorized for `Always` mode. Canceling the startup.")
						completion?(false)
						break
					}
				}
			case .denied, .notAvailable:
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
	public func add(message: MMGeoMessage, completion: (() -> Void)? = nil) {
		locationManagerQueue.executeAsync() {
			MMLogDebug("[GeofencingService] trying to add a message")
			guard self.isRunning == true else
			{
				MMLogDebug("[GeofencingService] isRunning = \(self.isRunning). Cancelling...")
				completion?()
				return
			}
			
			self.datasource.add(message: message)
			self.delegate?.didAddMessage(message: message)
			MMLogDebug("[GeofencingService] added a message\n\(message)")
			self.refreshMonitoredRegions(newRegions: message.regions, completion: completion)
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
	init(mmContext: MobileMessaging) {
		super.init()
		registerSelfAsSubservice(of: mmContext)
		
		locationManagerQueue.executeSync() {
			self.geofencingServiceQueue = RemoteAPIQueue(mmContext: mmContext, baseURL: mmContext.remoteAPIBaseURL, applicationCode: mmContext.applicationCode)
			self.locationManager = CLLocationManager()
			self.locationManager.delegate = self
			self.locationManager.distanceFilter = GeofencingConstants.distanceFilter
			self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
			self.datasource = GeofencingDatasource(storage: mmContext.internalStorage)
			self.mmContext = mmContext
			self.previousLocation = MobileMessaging.currentInstallation?.location
		}
	}
	
	deinit {
		NotificationCenter.default.removeObserver(self)
		eventsHandlingQueue.cancelAllOperations()
	}
	
	class var isDescriptionProvidedForWhenInUseUsage: Bool {
		return Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") != nil
	}
	
	class var isDescriptionProvidedForAlwaysUsage: Bool {
		return Bundle.main.object(forInfoDictionaryKey: "NSLocationAlwaysUsageDescription") != nil
	}
	
	func authorizeService(kind: LocationServiceKind, usage: LocationServiceUsage, completion: @escaping (GeofencingCapabilityStatus) -> Void) {
		locationManagerQueue.executeAsync() {
			guard self.capabilityCompletion == nil else
			{
				fatalError("Attempting to authorize location when a request is already in-flight")
			}
			
			let locationServicesEnabled = CLLocationManager.locationServicesEnabled()
			let regionMonitoringAvailable = CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self)
			guard locationServicesEnabled && (!kind.contains(options: LocationServiceKind.regionMonitoring) || regionMonitoringAvailable) else
			{
				MMLogDebug("[GeofencingService] not available (locationServicesEnabled = \(locationServicesEnabled), regionMonitoringAvailable = \(regionMonitoringAvailable))")
				completion(.notAvailable)
				return
			}
			
			self.capabilityCompletion = completion
			self.desirableUsageKind = usage
			
			switch usage {
			case .whenInUse:
				MMLogDebug("[GeofencingService] requesting 'WhenInUse'")
				
				if !GeofencingService.isDescriptionProvidedForWhenInUseUsage {
					MMLogDebug("[GeofencingService] NSLocationWhenInUseUsageDescription is not defined. Geo service cannot be used")
					completion(.notAvailable)
				} else {
					self.locationManager.requestWhenInUseAuthorization()
				}
			case .always:
				MMLogDebug("[GeofencingService] requesting 'Always'")
				
				if !GeofencingService.isDescriptionProvidedForAlwaysUsage {
					MMLogDebug("[GeofencingService] NSLocationAlwaysUsageDescription is not defined. Geo service cannot be used")
					completion(.notAvailable)
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
		let notExpiredRegions = Set(datasource.liveRegions.map { $0.circularRegion })
		let number = GeofencingConstants.monitoringRegionsLimit - monitoredRegions.count
		let location = locationManager.location ?? previousLocation
		let array = GeofencingService.closestLiveRegions(withNumberLimit: number, forLocation: location, fromRegions: notExpiredRegions, filter: { monitoredRegions.contains($0) == false })
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
	
	class func currentCapabilityStatus(forService kind: LocationServiceKind, usage: LocationServiceUsage) -> GeofencingCapabilityStatus {
		guard CLLocationManager.locationServicesEnabled() && (!kind.contains(options: LocationServiceKind.regionMonitoring) || CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self)) else
		{
			return .notAvailable
		}
		
		if (usage == .whenInUse && !GeofencingService.isDescriptionProvidedForWhenInUseUsage) || (usage == .always && !GeofencingService.isDescriptionProvidedForAlwaysUsage) {
			return .notAvailable
		}
		
		switch CLLocationManager.authorizationStatus() {
		case .notDetermined: return .notDetermined
		case .restricted: return .notAvailable
		case .denied: return .denied
		case .authorizedAlways: return .authorized
		case .authorizedWhenInUse:
			if usage == LocationServiceUsage.whenInUse {
				return .authorized
			} else {
				// the user wants .Always, but has .WhenInUse
				// return .NotDetermined so that we can prompt to upgrade the permission
				return .notDetermined
			}
		}
	}
	
	// MARK: - Private
	fileprivate var desirableUsageKind = LocationServiceUsage.whenInUse
	
	fileprivate var capabilityCompletion: ((GeofencingCapabilityStatus) -> Void)?
	
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
			
			NotificationCenter.default.addObserver(self, selector: #selector(GeofencingService.handleApplicationDidFinishLaunchingNotification(_:)), name: NSNotification.Name.UIApplicationDidFinishLaunching, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(GeofencingService.handleApplicationDidEnterBackgroundNotification(_:)), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(GeofencingService.handleApplicationDidBecomeActiveNotification(_:)), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
			
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
			return result +
				self.datasource.regionsDictionary.filter { $0.0.hasSuffix(region.identifier) }.map{ $0.1 }
		}
	}
	
	fileprivate func refreshMonitoredRegions(newRegions: Set<MMRegion>? = nil, completion: (() -> Void)? = nil) {
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
				completion?()
				return
			}
			let monitoredDataSourceRegionsArr = self.dataSourceRegions(from: monitoredRegions)
			let monitoredDatasourceRegions = Set(monitoredDataSourceRegionsArr) // assert 2
			let intersection = monitoredDatasourceRegions.filter({ (region) -> Bool in
				return newRegions.contains(where: {$0.dataSourceIdentifier == region.dataSourceIdentifier})
			})
			
			let group = DispatchGroup()
			group.enter()
			group.leave()
			intersection.forEach({ (region) in
				MMLogDebug("[GeofencingService] start checking new added region \(region)")
				if let currentCoordinate = self.locationManager.location?.coordinate , region.circularRegion.contains(currentCoordinate) {
					MMLogDebug("[GeofencingService] we are inside new added region \(region)")
					if region.message?.isNowAppropriateTimeForEntryNotification ?? false {
						MMLogDebug("[GeofencingService] time is appropriate for region: \(region)")
						group.enter()
						self.onEnter(datasourceRegion: region) { group.leave() }
					}
				}
			})
			
			group.notify(queue: DispatchQueue.global(qos: .default), execute: { 
				completion?()
			})
		}
	}
	
	fileprivate var previousLocation: CLLocation?
	
	//MARK: Notifications handling
	
	func handleApplicationDidFinishLaunchingNotification(_ notification: Notification) {
		assert(Thread .isMainThread)
		if notification.userInfo?[UIApplicationLaunchOptionsKey.location] != nil {
			MMLogDebug("[GeofencingService] The app relaunched by the OS.")
			restartLocationManager()
		}
	}
	
	func handleApplicationDidEnterBackgroundNotification(_ notification: Notification) {
		MMLogDebug("[GeofencingService] App did enter background.")
		assert(Thread .isMainThread)
		restartLocationManager()
		if let previousLocation = previousLocation {
			MobileMessaging.currentInstallation?.location = previousLocation
		}
	}
	
	func handleApplicationDidBecomeActiveNotification(_ notification: Notification) {
		MMLogDebug("[GeofencingService] App did become active.")
		assert(Thread .isMainThread)
		restartLocationManager()
	}
}


extension GeofencingService {
	@nonobjc static var currentDate: Date? // @nonobjc is to shut up the "A declaration cannot be both 'final' and 'dynamic'" error
	
	static func isGeoCampaignNotExpired(campaign: MMGeoMessage) -> Bool {
		let now = GeofencingService.currentDate ?? MobileMessaging.date.now
		
		return campaign.campaignState == .Active && now.compare(campaign.expiryTime) == .orderedAscending && campaign.hasValidEventsStateInGeneral
	}
	
	static func isNowAppropriateDay(forDeliveryTime dt: DeliveryTime) -> Bool {
		guard let days = dt.days, !days.isEmpty else {
			return true
		}
		let now = GeofencingService.currentDate ?? MobileMessaging.date.now
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
		let now = GeofencingService.currentDate ?? MobileMessaging.date.now
		return DeliveryTimeInterval.isTime(now, between: dti.fromTime, and: dti.toTime)
	}
	
	static func isRegionEventValidNow(_ regionEvent: RegionEvent) -> Bool {
		guard GeofencingService.isRegionEventValidInGeneral(regionEvent) else {
			return false
		}
		let now = GeofencingService.currentDate ?? MobileMessaging.date.now
		return regionEvent.lastOccuring?.addingTimeInterval(TimeInterval(regionEvent.timeout * 60)).compare(now) != .orderedDescending
	}
	
	static func isRegionEventValidInGeneral(_ regionEvent: RegionEvent) -> Bool {
		return !regionEvent.hasReachedTheOccuringLimit
	}
}

extension GeofencingService: CLLocationManagerDelegate {
	public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
		assert(Thread.isMainThread)
		MMLogDebug("[GeofencingService] locationManager did change the authorization status \(status.rawValue)")
		if let completion = self.capabilityCompletion , manager == self.locationManager && status != .notDetermined {
			self.capabilityCompletion = nil
			
			switch status {
			case .authorizedAlways:
				completion(.authorized)
			case .authorizedWhenInUse:
				completion(self.desirableUsageKind == LocationServiceUsage.whenInUse ? .authorized : .denied)
			case .denied:
				completion(.denied)
			case .restricted:
				completion(.notAvailable)
			case .notDetermined:
				fatalError("Unreachable due to the if statement, but included to keep clang happy")
			}
		}
		
		switch (self.isRunning, status) {
		case (true, let status) where !GeofencingConstants.supportedAuthStatuses.contains(status):
			stop()
		case (false, let status) where GeofencingConstants.supportedAuthStatuses.contains(status):
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
		datasource.validRegionsForEntryEventNow(with: region.identifier)?.forEach { datasourceRegion in
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
        return distanceFromPreviousPoint > GeofencingConstants.regionRefreshThreshold && monitorableRegionsCount > GeofencingConstants.monitoringRegionsLimit
    }
}


extension GeofencingService {
	
	func onEnter(datasourceRegion: MMRegion, completion: (() -> Void)? = nil) {
		assert(Thread.isMainThread)
		guard let message = datasourceRegion.message else {
			completion?()
			return
		}
		
		report(on: .entry, forRegionId: datasourceRegion.identifier, geoMessage: message, completion: { campaignState in
			MMLogDebug("[GeofencingService] did enter region \(datasourceRegion), campaign state: \(campaignState.rawValue)")
			if campaignState == .Active {
				self.didEnterActiveCampaignRegion(datasourceRegion)
			}
			completion?()
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
			if let scIds = eventsReportingResponse?.value?.suspendedCampaignIds, scIds.contains(geoMessage.campaignId) {
				campaignState = .Suspended
			} else if let fcIds = eventsReportingResponse?.value?.finishedCampaignIds, fcIds.contains(geoMessage.campaignId) {
				campaignState = .Finished
			} else {
				campaignState = .Active
			}
			
			completion?(campaignState)
		}
	}
	
	private func didEnterActiveCampaignRegion(_ datasourceRegion: MMRegion) {
		delegate?.didEnterRegion(region: datasourceRegion)
		
		GeofencingService.geoEventsHandler?.didEnter(region: datasourceRegion)
		
		NotificationCenter.mm_postNotificationFromMainThread(name: MMNotificationGeographicalRegionDidEnter, userInfo: [MMNotificationKeyGeographicalRegion: datasourceRegion])
	}
	
	private func reportOnEvents(completion: ((Result<GeoEventReportingResponse>?) -> ())?) {
		// we don't consider isRunning status here on purpose
		eventsHandlingQueue.addOperation(GeoEventReportingOperation(context: self.datasource.context, mmContext: mmContext, geoContext: self, finishBlock: { result in
			completion?(result)
		}))
	}
	
    private func refreshDatasource() {
        datasource.reload()
    }
	
	func syncWithServer(completion: ((Result<GeoEventReportingResponse>?) -> ())? = nil) {
		reportOnEvents(completion: completion)
	}
}
