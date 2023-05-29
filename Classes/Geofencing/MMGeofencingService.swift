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
	public class var geofencingService: MMGeofencingService? {
		if MMGeofencingService.sharedInstance == nil {
			guard let defaultContext = MobileMessaging.sharedInstance else {
				return nil
			}
			MMGeofencingService.sharedInstance = MMGeofencingService(mmContext: defaultContext)
		}
		return MMGeofencingService.sharedInstance
	}
	
	/// Fabric method for Mobile Messaging session.
	/// Use this method to enable the Geofencing service.
	public func withGeofencingService() -> MobileMessaging {
		MMGeofencingService.isGeoServiceNeedsToStart = true
		if MMGeofencingService.sharedInstance == nil {
			MMGeofencingService.sharedInstance = MMGeofencingService(mmContext: self)
		}
		return self
	}
}

@objcMembers
public class MMGeofencingService: MobileMessagingService {

    lazy var remoteApiProvider: GeoRemoteAPIProvider! = GeoRemoteAPIProvider(sessionManager: self.mmContext.httpSessionManager)

    /// Starts the Geofencing Service
    ///
    /// During the startup process, the service automatically asks user to grant the appropriate permissions
    /// Once the user granted the permissions, the service succesfully lauches.
    /// - parameter completion: A block that will be triggered once the startup process is finished. Contains a Bool flag parameter, that indicates whether the startup succeded.
    override public func start(_ completion: @escaping (Bool) -> Void) {
        logDebug("starting ...")
        
        locationManagerQueue.async {
            self.datasource = GeofencingInMemoryDatasource(storage: self.mmContext.internalStorage)
            self.previousLocation = self.mmContext.internalData().location
            
            guard self.isRunning == false else
            {
                self.logDebug("isRunning = \(self.isRunning). Cancelling...")
                completion(false)
                return
            }
            
            let currentCapability = type(of: self).currentCapabilityStatus
            switch currentCapability {
            case .authorized:
                self.startService()
                completion(true)
            case .notDetermined:
                self.logDebug("capability is 'not determined', authorizing...")
                self.authorizeService(kind: MMLocationServiceKind.regionMonitoring, usage: GeoConstants.preferableUsage) { capability in
                    switch capability {
                    case .authorized:
                        self.logDebug("successfully authorized for `Always` mode")
                        self.startService()
                        completion(true)
                    default:
                        self.logDebug("was not authorized for `Always` mode. Canceling the startup.")
                        completion(false)
                        break
                    }
                }
            case .denied, .notAvailable:
                self.logDebug("capability is \(currentCapability.rawValue). Canceling the startup.")
                completion(false)
            }
            self.syncWithServer({_ in})
        }
    }
    
    /// Stops the Geofencing Service
    override public func suspend() {
        logDebug("Suspending")
        locationManagerQueue.async {
            guard self.isRunning == true else {
                return
            }
            super.suspend()
            self.locationManager.stopMonitoringSignificantLocationChanges()
            self.locationManager.stopUpdatingLocation()
            self.stopMonitoringMonitoredRegions() {
                self.logDebug("Suspended")
            }
        }
    }
    
    public override func stopService(_ completion: @escaping (Bool) -> Void) {
        self.locationManager.delegate = nil
        super.stopService(completion)
        cancelOperations()
        MMGeofencingService.sharedInstance = nil
    }
    
    override func depersonalizationStatusDidChange(_ completion: @escaping () -> Void) {
		switch mmContext.internalData().currentDepersonalizationStatus {
		case .pending:
            suspend()
            completion()
		case .success, .undefined:
			start({ _ in completion() })
		}
	}

    public override func depersonalizeService(_ mmContext: MobileMessaging, completion: @escaping () -> Void) {
		logDebug("depersonalizing")
        cancelOperations()
		self.stopMonitoringMonitoredRegions() {
			self.cleanup(completion)
		}
	}

	func syncWithServer(_ completion: @escaping (NSError?) -> Void) {
        syncWithServer(completion: { (result) in
			completion(result?.error)
		})
	}
	
    public override func mobileMessagingDidStart(_ completion: @escaping () -> Void) {
		guard MMGeofencingService.isGeoServiceNeedsToStart && mmContext.currentInstallation().isPushRegistrationEnabled && mmContext.internalData().currentDepersonalizationStatus == .undefined else {
            completion()
			return
		}
		MMGeofencingService.isGeoServiceNeedsToStart = false
		start({ _ in completion() })
	}

	override func pushRegistrationStatusDidChange(_ completion: @escaping () -> Void) {
		if mmContext.currentInstallation().isPushRegistrationEnabled {
			start({ _ in completion() })
		} else {
            suspend()
            completion()
		}
	}
	
	override func populateNewPersistedMessage(_ message: inout MessageManagedObject, originalMessage: MM_MTMessage) -> Bool {
		guard let geoSignalingMessage = MMGeoMessage(payload: originalMessage.originalPayload,
													 deliveryMethod: MMMessageDeliveryMethod(rawValue: message.deliveryMethod) ?? .undefined,
													 seenDate: message.seenDate,
													 deliveryReportDate: message.deliveryReportedDate,
													 seenStatus: message.seenStatus,
													 isDeliveryReportSent: message.reportSent) else {
			logDebug("cannot populate message \(message.messageId)")
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
		logDebug("attributes fulfilled for message \(message.messageId)")
		return true
	}
	
    public override func handleNewMessage(_ message: MM_MTMessage, completion: @escaping (MessageHandlingResult) -> Void) {
		guard let geoSignalingMessage = MMGeoMessage(payload: message.originalPayload,
													 deliveryMethod: message.deliveryMethod,
													 seenDate: message.seenDate,
													 deliveryReportDate: message.deliveryReportedDate,
													 seenStatus: message.seenStatus,
													 isDeliveryReportSent: message.isDeliveryReportSent) else
		{
			completion(.noData)
			return
		}
		add(message: geoSignalingMessage) {
			completion(.noData)
		}
	}
    
    override func appDidFinishLaunching(_ notification: Notification, completion: @escaping () -> Void) {
        assert(!Thread.isMainThread)
        locationManagerQueue.async {
            if notification.userInfo?[UIApplication.LaunchOptionsKey.location] != nil {
                self.logDebug("The app relaunched by the OS.")
                self.restartLocationManager()
            }
            completion()
        }
    }

    public override func appWillEnterForeground(_ completion: @escaping () -> Void) {
        syncWithServer({_ in completion() })
    }

    override func appDidEnterBackground(_ completion: @escaping () -> Void) {
        logDebug("App did enter background.")
        assert(!Thread.isMainThread)
        locationManagerQueue.async {
            self.restartLocationManager()
            if let previousLocation = self.previousLocation {
                let internalData = self.mmContext.internalData()
                internalData.location = previousLocation
                internalData.archiveCurrent()
            }
            completion()
        }
    }
    
    override func appDidBecomeActive(_ completion: @escaping () -> Void) {
        logDebug("App did become active.")
        assert(!Thread.isMainThread)
        locationManagerQueue.async {
            self.restartLocationManager()
            completion()
        }
    }
	
	private var _isRunning: Bool = false
    public override var isRunning: Bool  {
		get {
			var ret: Bool = false
			locationManagerQueue.sync() {
				ret = self._isRunning
			}
			return ret
		}
		set {
			locationManagerQueue.sync() {
				self._isRunning = newValue
			}
		}
	}
    
    public override var systemData: [String: AnyHashable]? {
		return [Consts.SystemDataKeys.geofencingServiceEnabled: type(of: self).isSystemDataGeofencingServiceEnabled]
	}
    
    // MARK: -

	public static var isSystemDataGeofencingServiceEnabled: Bool {
        let status = currentCapabilityStatus
        if status == .notDetermined {
            return UserDefaults.standard.bool(forKey: GeoConstants.UserDefaultsKey.geoEnabledFlag)
        } else {
            UserDefaults.standard.set(status == .authorized, forKey: GeoConstants.UserDefaultsKey.geoEnabledFlag)
            return status == MMGeofencingCapabilityStatus.authorized
        }
	}
	
	static var isGeoServiceNeedsToStart: Bool = false
	static var sharedInstance: MMGeofencingService?
	var sessionManager: DynamicBaseUrlHTTPSessionManager!
	var locationManager: CLLocationManager!
	var datasource: GeofencingInMemoryDatasource!
    let locationManagerQueue = MMQueue.Main.queue
    private let q: DispatchQueue
    let eventsHandlingQueue: MMOperationQueue
	
	// MARK: - Public
	
	/// Returns current user location with accuracy `kCLLocationAccuracyHundredMeters`.
	public var currentUserLocation: CLLocation? { return locationManager.location }
	public weak var delegate: MMGeofencingServiceDelegate?
	
	/// Returns all the regions available in the Geofencing Service storage.
	public var allRegions: Array<MMRegion> {
		var result = Array<MMRegion>()
		locationManagerQueue.sync {
			result = self.datasource.allRegions
		}
		return result
	}
	
	/// Returns current capability status for Geofencing Service. For more information see `MMGeofencingCapabilityStatus`.
	public class var currentCapabilityStatus: MMGeofencingCapabilityStatus {
		return MMGeofencingService.currentCapabilityStatus(forService: MMLocationServiceKind.regionMonitoring, usage: GeoConstants.minimumAllowedUsage)
	}
	
	/// Requests permission to use location services whenever the app is running.
	/// - parameter usage: Defines the usage type for which permissions is requested.
	/// - parameter completion: A block that will be triggered once the authorization request is finished and the capability statys is defined. The current capability status is passed to the block as a parameter.
	public func authorize(usage: MMLocationServiceUsage, completion: @escaping (MMGeofencingCapabilityStatus) -> Void) {
		authorizeService(kind: MMLocationServiceKind.regionMonitoring, usage: usage, completion: completion)
	}
	
	/// Accepts a geo message, which contains regions that should be monitored.
	/// - parameter message: A message object to add to the monitoring. Object of `MMGeoMessage` class.
	public func add(message: MMGeoMessage, completion: @escaping (() -> Void)) {
		locationManagerQueue.async {
			self.logDebug("trying to add a message")
			guard self.isRunning == true else
			{
				self.logDebug("isRunning = \(self.isRunning). Cancelling...")
				completion()
				return
			}
			
			self.datasource.add(message: message)
			self.delegate?.didAddMessage(message: message)
			self.logDebug("added a message\n\(message)")
			self.refreshMonitoredRegions(newRegions: message.regions, completion: completion)
		}
	}
	
	/// Removes a message from the monitoring.
	public func removeMessage(withId messageId: String) {
		locationManagerQueue.async {
			self.datasource.removeMessage(withId: messageId)
			self.logDebug("message removed \(messageId)")
			self.refreshMonitoredRegions(completion: {})
		}
	}
	
	/// The geo event handling object defines the behaviour that is triggered during the geo event.
	///
	/// You can implement your own geo event handling either by subclassing `MMDefaultGeoEventHandling` or implementing the `MMGeoEventHandling` protocol.
	public static var geoEventsHandler: MMGeoEventHandling?
	
	// MARK: - Internal
	//FIXME: use background queue. (initialize separate NSThread which lives as long as geo service running)
	init(mmContext: MobileMessaging) {
        self.q = DispatchQueue(label: "geofencing-service", qos: DispatchQoS.default, attributes: .concurrent, autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit, target: nil)
        self.eventsHandlingQueue = MMOperationQueue.newSerialQueue(underlyingQueue: q)
        
		super.init(mmContext: mmContext, uniqueIdentifier: "GeofencingService")
		
		locationManagerQueue.sync {
			self.sessionManager = mmContext.httpSessionManager
			self.locationManager = CLLocationManager()
			self.locationManager.delegate = self
			self.locationManager.distanceFilter = GeoConstants.distanceFilter
			self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
		}
	}
	
	class var isDescriptionProvidedForWhenInUseUsage: Bool {
		return Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") != nil
	}
	
	class var isDescriptionProvidedForAlwaysUsage: Bool {
		return Bundle.main.object(forInfoDictionaryKey: "NSLocationAlwaysUsageDescription") != nil
	}

	@available(iOS 11.0, *)
	class var isDescriptionProvidedForAlwaysAndWhenInUseUsage: Bool {
		return Bundle.main.object(forInfoDictionaryKey: "NSLocationAlwaysAndWhenInUseUsageDescription") != nil
	}
	
	func authorizeService(kind: MMLocationServiceKind, usage: MMLocationServiceUsage, completion: @escaping (MMGeofencingCapabilityStatus) -> Void) {
		locationManagerQueue.async {
			guard self.capabilityCompletion == nil else
			{
				fatalError("Attempting to authorize location when a request is already in-flight")
			}
			
			let locationServicesEnabled = CLLocationManager.locationServicesEnabled()
			let regionMonitoringAvailable = CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self)
			guard locationServicesEnabled && (!kind.contains(options: MMLocationServiceKind.regionMonitoring) || regionMonitoringAvailable) else
			{
				self.logDebug("not available (locationServicesEnabled = \(locationServicesEnabled), regionMonitoringAvailable = \(regionMonitoringAvailable))")
				completion(.notAvailable)
				return
			}
			
			self.capabilityCompletion = completion
			self.desirableUsageKind = usage
			
			switch usage {
			case .whenInUse:
				self.logDebug("requesting 'WhenInUse'")
				
				if !MMGeofencingService.isDescriptionProvidedForWhenInUseUsage {
					self.logWarn("NSLocationWhenInUseUsageDescription is not defined. Geo service cannot be used")
					completion(.notAvailable)
				} else {
					self.locationManager.requestWhenInUseAuthorization()
				}
			case .always:
				self.logDebug("requesting 'Always'")
				
				if !MMGeofencingService.isDescriptionProvidedForAlwaysUsage {
					self.logWarn("NSLocationAlwaysUsageDescription is not defined. Geo service cannot be used")
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
		let number = GeoConstants.monitoringRegionsLimit - monitoredRegions.count
		let location = locationManager.location ?? previousLocation
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
	
	class func currentCapabilityStatus(forService kind: MMLocationServiceKind, usage: MMLocationServiceUsage) -> MMGeofencingCapabilityStatus {
		guard CLLocationManager.locationServicesEnabled() && (!kind.contains(options: MMLocationServiceKind.regionMonitoring) || CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self)) else
		{
			return .notAvailable
		}
		
		if (usage == .whenInUse && !MMGeofencingService.isDescriptionProvidedForWhenInUseUsage) || (usage == .always && !MMGeofencingService.isDescriptionProvidedForAlwaysUsage) {
			return .notAvailable
		}
		
        let ret: MMGeofencingCapabilityStatus
		switch CLLocationManager.authorizationStatus() {
            case .notDetermined: ret = .notDetermined
            case .restricted: ret = .notAvailable
            case .denied: ret = .denied
            case .authorizedAlways: ret = .authorized
            case .authorizedWhenInUse:
                switch usage {
                case MMLocationServiceUsage.whenInUse:
                    ret = .authorized
                case MMLocationServiceUsage.always:
                    // the user wants .Always, but has .WhenInUse
                    // return .NotDetermined so that we can prompt to upgrade the permission
                    ret = .notDetermined
                }
            @unknown default: ret = .notDetermined
		}
        return ret
	}
	
	// MARK: - Private
	fileprivate var desirableUsageKind = MMLocationServiceUsage.whenInUse
	
	fileprivate var capabilityCompletion: ((MMGeofencingCapabilityStatus) -> Void)?

	private func cancelOperations() {
		eventsHandlingQueue.cancelAllOperations()
	}

	private func cleanup(_ completion: @escaping () -> Void) {
		eventsHandlingQueue.addOperation(GeoCleanupOperation(datasource: datasource, finishBlock: { _ in
			completion()
		}))
	}

	fileprivate func restartLocationManager() {
		if MobileMessaging.application.applicationState == UIApplication.State.active {
			if CLLocationManager.significantLocationChangeMonitoringAvailable() {
				self.locationManager.stopMonitoringSignificantLocationChanges()
				logDebug("stopped updating significant location changes")
			}
			self.locationManager.startUpdatingLocation()
			logDebug("started updating location")
		} else {
			self.locationManager.stopUpdatingLocation()
			logDebug("stopped updating location")
			if CLLocationManager.significantLocationChangeMonitoringAvailable() {
				self.locationManager.startMonitoringSignificantLocationChanges()
				logDebug("started updating significant location changes")
			}
		}
	}

	fileprivate func startService() {
		locationManagerQueue.async {
			guard self.isRunning == false else {
				return
			}
            super.start { _ in
                self.restartLocationManager()
                self.refreshMonitoredRegions(completion: {})
                UserEventsManager.postGeoServiceStartedEvent()
                self.logDebug("started.")
            }
		}
	}

	fileprivate func stopMonitoringMonitoredRegions(completion: @escaping () -> Void) {
		locationManagerQueue.async {
			self.logDebug("stopping monitoring all regions")
			for monitoredRegion in self.locationManager.monitoredRegions {
				self.locationManager.stopMonitoring(for: monitoredRegion)
			}
			completion()
		}
	}
	
	fileprivate func dataSourceRegions(from circularRegions: Set<CLCircularRegion>) -> [MMRegion] {
		return circularRegions.reduce([MMRegion]()) { (result, region) -> [MMRegion] in
			return result +
				self.datasource.regionsDictionary.filter { $0.0.hasSuffix(region.identifier) }.map{ $0.1 }
		}
	}
	
	fileprivate func triggerEventsForRegionsInCaseWeAreInside(_ monitoredNewRegions: Set<MMRegion>, completion: @escaping () -> Void) {
		/// It was decided to implement following solution: Among concurring nested regions (within the same campaign) that user is already staying in, the smallest should win, the rest should not trigger. It's a temporary solution, more logical would be to trigger the area which has nearest center.
		guard let currentCoordinate = self.locationManager.location?.coordinate else {
			logDebug("current coordinate is undefined")
			completion()
			return
		}
		
		let campaignsRegions = monitoredNewRegions.filter({ region in
			return region.circularRegion.contains(currentCoordinate) && region.message?.isNowAppropriateTimeForEntryNotification ?? false
		}).reduce(Dictionary<String, MMRegion>(), { (campaignsRegions, region) -> Dictionary<String, MMRegion> in
			guard let campaignId = region.message?.campaignId else {
				return campaignsRegions
			}
			
			let ret: MMRegion
			if let savedRegion = campaignsRegions[campaignId] {
				ret = region.radius < savedRegion.radius ? region : savedRegion
			} else {
				ret = region
			}
			return [campaignId : ret]
		})
		
		let group = DispatchGroup()

		campaignsRegions.values.forEach { region in
			logDebug("you are already in region \(region), triggering entering event...")
			group.enter()
			self.onEnter(datasourceRegion: region) { group.leave() }
		}
		group.notify(queue: DispatchQueue.global(qos: .default), execute: completion)
	}
	
	fileprivate func refreshMonitoredRegions(newRegions: Set<MMRegion>? = nil, completion: @escaping (() -> Void)) {
		locationManagerQueue.async {
			
			var monitoredRegions: Set<CLCircularRegion> = Set(self.locationManager.monitoredRegions.compactMap { $0 as? CLCircularRegion })
			self.logDebug("refreshing monitored regions: \n\(monitoredRegions) \n datasource regions: \n \(self.datasource.regionsDictionary)")
			
			//check what to stop
			let regionsToStopMonitoring = self.regionsToStopMonitoring(monitoredRegions: monitoredRegions)
			self.logDebug("will stop monitoring regions: \n\(self.dataSourceRegions(from: regionsToStopMonitoring))")
			regionsToStopMonitoring.forEach{self.locationManager.stopMonitoring(for: $0)}
			monitoredRegions.subtract(regionsToStopMonitoring)
			
			//check what to start
			let regionsToStartMonitoring = self.regionsToStartMonitoring(monitoredRegions: monitoredRegions)
			self.logDebug("will start monitoring regions: \n\(self.dataSourceRegions(from: regionsToStartMonitoring))")
			
			regionsToStartMonitoring.forEach({ (region) in
				region.notifyOnEntry = true
				region.notifyOnExit = true
				self.locationManager.startMonitoring(for: region)
			})
			monitoredRegions.formUnion(regionsToStartMonitoring)
			
			//try to enter, if we are already inside added region
			guard let newRegions = newRegions else {
				completion()
				return
			}
			let monitoredDataSourceRegionsArr = self.dataSourceRegions(from: monitoredRegions)
			let monitoredDatasourceRegions = Set(monitoredDataSourceRegionsArr) // assert 2
			let monitoredNewRegions = monitoredDatasourceRegions.filter({ (region) -> Bool in
				return newRegions.contains(where: {$0.dataSourceIdentifier == region.dataSourceIdentifier})
			})
			
			self.triggerEventsForRegionsInCaseWeAreInside(Set(monitoredNewRegions), completion: completion)
		}
	}
	
	fileprivate var previousLocation: CLLocation?
}

extension MMGeofencingService: CLLocationManagerDelegate {
	public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
		assert(Thread.isMainThread)
		logDebug("locationManager did change the authorization status \(status.rawValue)")
		if let completion = self.capabilityCompletion , manager == self.locationManager && status != .notDetermined {
			self.capabilityCompletion = nil
            

            let geofencingCapabilityStatus: MMGeofencingCapabilityStatus
            switch status {
			case .authorizedAlways:
                geofencingCapabilityStatus = .authorized
			case .authorizedWhenInUse:
                geofencingCapabilityStatus = self.desirableUsageKind == MMLocationServiceUsage.whenInUse ? .authorized : .denied
			case .denied:
                geofencingCapabilityStatus = .denied
			case .restricted:
                geofencingCapabilityStatus = .notAvailable
			case .notDetermined:
				fatalError("Unreachable due to the if statement, but included to keep clang happy")
			@unknown default:
                geofencingCapabilityStatus = .notDetermined
			}
            completion(geofencingCapabilityStatus)
		}
		
        switch (self.isRunning, status) {
        case (true, let status) where !GeoConstants.supportedAuthStatuses.contains(status):
            suspend()
        case (false, let status) where GeoConstants.supportedAuthStatuses.contains(status):
            start({ _ in })
        default:
            break
		}
	}
	
	public func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
		assert(Thread.isMainThread)
		logDebug("did start monitoring for region: \(region)")
	}
	
	public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
		assert(Thread.isMainThread)
		logDebug("will enter region \(region)")
		datasource.validRegionsForEntryEventNow(with: region.identifier)?.forEach { datasourceRegion in
			onEnter(datasourceRegion: datasourceRegion) {}
		}
	}
	
	public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
		assert(Thread.isMainThread)
		logError("did fail with error \(error)")
	}
	
	public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		assert(Thread.isMainThread)
		logDebug("did update locations")
		guard let location = locations.last else
        {
			return
		}
		if self.shouldRefreshRegionsWithNewLocation(location: location) {
			self.previousLocation = location
			self.refreshMonitoredRegions(completion: {})
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
        logDebug("distance from previous point = \(distanceFromPreviousPoint), monitorableRegionsCount = \(monitorableRegionsCount)")
        return distanceFromPreviousPoint > GeoConstants.regionRefreshThreshold && monitorableRegionsCount > GeoConstants.monitoringRegionsLimit
    }
	
	func onEnter(datasourceRegion: MMRegion, completion: @escaping () -> Void) {
		assert(Thread.isMainThread)
		guard let message = datasourceRegion.message else {
			completion()
			return
		}
		
		report(on: .entry, forRegionId: datasourceRegion.identifier, geoMessage: message, completion: { campaignState in
			self.logDebug("did enter region \(datasourceRegion), campaign state: \(campaignState.rawValue)")
			if campaignState == .Active {
				self.didEnterActiveCampaignRegion(datasourceRegion)
			}
			completion()
		})
	}
	
	func report(on eventType: RegionEventType, forRegionId regionId: String, geoMessage: MMGeoMessage, completion: @escaping (MMCampaignState) -> Void) {
		eventsHandlingQueue.addOperation(GeoEventPersistingOperation(geoMessage: geoMessage, regionId: regionId, eventType: eventType, context: datasource.context, finishBlock: { _ in }))
		
        reportOnEvents { eventsReportingResponse in

            self.refreshDatasource()
            
			let campaignState: MMCampaignState
			if let scIds = eventsReportingResponse?.value?.suspendedCampaignIds, scIds.contains(geoMessage.campaignId) {
				campaignState = .Suspended
			} else if let fcIds = eventsReportingResponse?.value?.finishedCampaignIds, fcIds.contains(geoMessage.campaignId) {
				campaignState = .Finished
			} else {
				campaignState = .Active
			}
			
			completion(campaignState)
		}
	}
	
	private func didEnterActiveCampaignRegion(_ datasourceRegion: MMRegion) {
		delegate?.didEnterRegion(region: datasourceRegion)
		
		MMGeofencingService.geoEventsHandler?.didEnter(region: datasourceRegion)

		UserEventsManager.postGeoRegionEnteredEvent(datasourceRegion)
	}
	
	private func reportOnEvents(completion: @escaping (GeoEventReportingResult?) -> ()) {
		// we don't consider isRunning status here on purpose
		eventsHandlingQueue.addOperation(GeoEventReportingOperation(context: datasource.context, mmContext: mmContext, geoContext: self, finishBlock: { result in
			completion(result)
		}))
	}
    
    func syncWithServer(completion: @escaping (GeoEventReportingResult?) -> ()) {
        reportOnEvents(completion: completion)
    }
	
    private func refreshDatasource() {
        datasource.reload()
    }
}

extension UserEventsManager {
	class func postGeoRegionEnteredEvent(_ datasourceRegion: MMRegion) {
		post(MMNotificationGeographicalRegionDidEnter, [MMNotificationKeyGeographicalRegion: datasourceRegion])
	}
}
