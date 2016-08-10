//
//  MMRegionMonitoringManager.swift
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

public protocol MMRegionMonitoringManagerProtocol: class {
	func didAddCampaing(campaign: MMCampaign)
	func didEnterRegion(region: MMRegion)
	func didExitRegion(region: MMRegion)
}

public class MMRegionMonitoringManager: NSObject, CLLocationManagerDelegate {
	let locationManager: CLLocationManager
	let datasource: MMGeofencingDatasource
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
	
	public var currentUserLocation: CLLocation? {
		return locationManager.location
	}
	
	public static let sharedInstance = MMRegionMonitoringManager()
	
	public weak var delegate: MMRegionMonitoringManagerProtocol?

	public var allCampaings: Set<MMCampaign> {
		return datasource.campaigns
	}
	
	public var allRegions: Set<MMRegion> {
		return datasource.regions
	}
	
	override init() {
		locationManager = CLLocationManager()
		datasource = MMGeofencingDatasource()
		super.init()
		
		// It is important to set location manager delegate as soon as MMLocationManager is created. This is important because application can be terminated.
		// New region event will start application in the background and deliver event to newly created CLLocationManager object in shared MMLocationManager.
		// When this is set MMNotificationGeographicalRegionDidEnter and MMNotificationGeographicalRegionDidExit will be posted.
		locationManager.delegate = self
		locationManager.distanceFilter = 100
		locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
	}
	
	private func currentCapabilityStatusForService(kind: MMLocationServiceKind, usage: MMLocationServiceUsage) -> MMCapabilityStatus {
		guard CLLocationManager.locationServicesEnabled() && (!kind.contains(MMLocationServiceKind.RegionMonitoring) || CLLocationManager.isMonitoringAvailableForClass(CLCircularRegion)) else
		{
			return .NotAvailable
		}
		
		let actual = CLLocationManager.authorizationStatus()
		
		switch actual {
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
	
	public func authorizeService(kind: MMLocationServiceKind, usage: MMLocationServiceUsage, completion: MMCapabilityStatus -> Void) {
		guard self.completion == nil else
		{
			fatalError("Attempting to authorize location when a request is already in-flight")
		}
		
		guard CLLocationManager.locationServicesEnabled() && (!kind.contains(MMLocationServiceKind.RegionMonitoring) || CLLocationManager.isMonitoringAvailableForClass(CLCircularRegion)) else
		{
			completion(.NotAvailable)
			return
		}
		
		self.completion = completion
		self.usageKind = usage
		
		let key: String
		switch usage {
		case .WhenInUse:
			key = "NSLocationWhenInUseUsageDescription"
			locationManager.requestWhenInUseAuthorization()
			
		case .Always:
			key = "NSLocationAlwaysUsageDescription"
			locationManager.requestAlwaysAuthorization()
		}
		
		// This is helpful when developing an app.
		assert(NSBundle.mainBundle().objectForInfoDictionaryKey(key) != nil, "Requesting location permission requires the \(key) key in your Info.plist")
	}
	
	public func startMonitoringCampaignsRegions(completion: (Bool -> Void)? = nil) {
		guard locationManagerEnabled == true && isRunning == false else
		{
			completion?(false)
			return
		}
		
		switch currentCapabilityStatusForService(MMLocationServiceKind.RegionMonitoring, usage: .Always) {
		case .Authorized:
			self.start()
			completion?(true)
		case .NotDetermined:
			authorizeService(MMLocationServiceKind.RegionMonitoring, usage: .Always) { status in
				switch status {
				case .Authorized:
					self.start()
					completion?(true)
				default:
					completion?(false)
					break
				}
			}
		case .Denied, .NotAvailable:
			completion?(false)
		}
	}
	
	public func stop() {
		guard isRunning == true else
		{
			return
		}
		
		isRunning = false
		locationManager.delegate = nil
		locationManager.stopMonitoringSignificantLocationChanges()
		locationManager.stopUpdatingLocation()
		
		stopMonitoringMonitoredRegions()
		
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}
	
	public func addCampaingToRegionMonitoring(campaign: MMCampaign) {
		guard locationManagerEnabled == true && isRunning == true else
		{
			return
		}
		
		datasource.addNewCampaign(campaign)
		delegate?.didAddCampaing(campaign)
		refreshMonitoredRegions()
	}
	
	public func removeCampaignFromRegionMonitoring(campaing: MMCampaign) {
		datasource.removeCampaign(campaing)
		refreshMonitoredRegions()
	}
	
	public func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
		if let completion = self.completion where manager == self.locationManager && status != .NotDetermined {
			self.completion = nil
			
			switch status {
			case .AuthorizedAlways:
				completion(.Authorized)
			case .AuthorizedWhenInUse:
				completion(usageKind == .WhenInUse ? .Authorized : .Denied)
			case .Denied:
				completion(.Denied)
			case .Restricted:
				completion(.NotAvailable)
			case .NotDetermined:
				fatalError("Unreachable due to the if statement, but included to keep clang happy")
			}
		}
		
		if isRunning {
			switch status {
			case .AuthorizedWhenInUse, .Denied, .Restricted, .NotDetermined:
				stop()
			default:
				break
			}
		} else {
			switch status {
			case .AuthorizedAlways:
				start()
			default:
				break
			}
		}
	}
	
	// MARK: - Private
	private var usageKind = MMLocationServiceUsage.WhenInUse
	
	private var completion: (MMCapabilityStatus -> Void)?
	
	private func start() {
		guard locationManagerEnabled == true && isRunning == false else
		{
			return
		}
		
		locationManager.startUpdatingLocation()
		
		// When app is moving to the background stop standard location service and start
		// significant location change service if available.
		NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationWillResignActiveNotification, object: nil, queue: nil, usingBlock:
			{ [weak self] note in
				self?.locationManager.stopUpdatingLocation()
				if CLLocationManager.significantLocationChangeMonitoringAvailable() {
					self?.locationManager.startMonitoringSignificantLocationChanges()
				} else {
					MMLogInfo("Significant location change monitoring is not available.")
				}
			}
		)
		
		// When app is moving to the foreground stop the significatn location change
		// and start the stand
		NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationWillEnterForegroundNotification, object: nil, queue: nil, usingBlock:
			{ [weak self] note in
				self?.locationManager.startUpdatingLocation()
				if CLLocationManager.significantLocationChangeMonitoringAvailable() {
					self?.locationManager.stopMonitoringSignificantLocationChanges()
				} else {
					MMLogInfo("Significant location change monitoring is not available.")
				}
			}
		)
		isRunning = true
		
		// Load saved (already received) campaings and start monitoring them.
		refreshMonitoredRegions()
	}
	
	private func stopMonitoringMonitoredRegions() {
		for monitoredRegion in locationManager.monitoredRegions {
			locationManager.stopMonitoringForRegion(monitoredRegion)
		}
	}
	
	private func refreshMonitoredRegions() {
		startMonitoringCampaigns(datasource.campaigns)
	}
	
	private func addRegionToMonitor(region: MMRegion) {
		//FIXME: move the check to authorization stage
		let newMonioredRegion = CLCircularRegion(center: region.center,
												 radius: region.radius,
												 identifier: region.id)
		newMonioredRegion.notifyOnEntry = true
		newMonioredRegion.notifyOnExit = true
		locationManager.startMonitoringForRegion(newMonioredRegion)
	}
	
	private func stopMonitoringRegion(region: MMRegion) {
		for monitoredRegion in locationManager.monitoredRegions where monitoredRegion.identifier == region.id {
			locationManager.stopMonitoringForRegion(monitoredRegion)
		}
	}
	
	private func startMonitoringCampaigns(campaigns: Set<MMCampaign>) {
		stopMonitoringMonitoredRegions()
		
		for region in findTwentyClosestRegions(campaigns) {
			addRegionToMonitor(region)
		}
	}
	
	private func postNotificationsForMonitoredRegions(name: String, regionId: String) {
		for reg in MMGeofencingDatasource.sharedInstance.regions where reg.id == regionId {
			delegate?.didEnterRegion(reg)
			//FIXME: must remove region from monitoring. and never add it again.
			NSNotificationCenter.mm_postNotificationFromMainThread(name, userInfo: [MMNotificationKeyGeographicalRegion: reg])
		}
	}
	
	// Apple region monitor can monitor only 20 regions per application. If there are
	// more than 20 regions installed +to monitor we have to find 20 closest regions.
	private func findTwentyClosestRegions(campaigns: Set<MMCampaign>) ->  [MMRegion] {
		let allRegions: [MMRegion] = Array(datasource.regions)
		guard let currentLocation = locationManager.location else
		{
			return Array(allRegions[0..<min(20, allRegions.count)])
		}
		
		let sortedRegions = allRegions.sort { region1, region2 in
			let location1 = CLLocation(latitude: region1.center.latitude, longitude: region1.center.longitude)
			let location2 = CLLocation(latitude: region2.center.latitude, longitude: region2.center.longitude)
			return currentLocation.distanceFromLocation(location1) < currentLocation.distanceFromLocation(location2)
		}
		
		return Array(sortedRegions[0..<min(20, sortedRegions.count)])
	}
	
	// MARK: - Location Manager delegate
	public func locationManager(manager: CLLocationManager, didEnterRegion region: CLRegion) {
		postNotificationsForMonitoredRegions(MMNotificationGeographicalRegionDidEnter, regionId: region.identifier)
	}
	
	public func locationManager(manager: CLLocationManager, didExitRegion region: CLRegion) {
		postNotificationsForMonitoredRegions(MMNotificationGeographicalRegionDidExit, regionId: region.identifier)
	}
	
	public func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		refreshMonitoredRegions()
	}
}
