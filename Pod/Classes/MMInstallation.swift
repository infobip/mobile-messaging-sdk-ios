//
//  MMInstallation.swift
//  MobileMessaging
//
//  Created by Andrey K. on 17/02/16.
//  
//

import CoreData
import Foundation

final public class MMInstallation : NSObject {
	
	deinit {
		ManagedObjectNotificationCenter.defaultCenter.removeAllObservers()
	}
	
	//MARK: Public
	public override var description: String {
		return "Installation:\n  Device token = \(deviceToken)\n  Internal registration ID = \(internalId)\n  Metadata = \(metaData)"
	}
	
	/**
	A read-only opaque identifier assigned by APNs to a specific app on a specific device. Each app instance receives its unique token when it registers with APNs and must share this token with its provider.
	*/
	public internal(set) var deviceToken: String? {
		get { return installationManager.getValueForKey("deviceToken") as? String }
		set { installationManager.setValueForKey("deviceToken", value: newValue) }
	}
	
	/**
	A read-only identifier provided by server to uniquely identify the current app instance on a specific device.
	*/
	public internal(set) var internalId: String? {
		get { return installationManager.getValueForKey("internalId") as? String }
		set { installationManager.setValueForKey("internalId", value: newValue) }
	}
	
	/**
	A users email address. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user message is aimed and other nice features.
	*/
	public var email: String? {
		get { return installationManager.getValueForKey("email") as? String }
	}
	
	/**
	Saves an email to the server and executes the given completion block.
	- parameter email: An email you want to link with the current user.
	- parameter completion: The block to execute after the server responded.
	*/
	public func saveEmail(email: String, completion: (NSError?) -> ()) {
		installationManager.saveEmail(email, completion: completion)
	}
	
	/**
	A users MSISDN. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user message is aimed and other nice features.
	*/
	public var msisdn: String? {
		get { return installationManager.getValueForKey("msisdn") as? String }
	}
	
	/**
	Saves a MSISDN to the server and executes the given completion block.
	- parameter msisdn: A MSISDN you want to link with the current user.
	- parameter completion: The block to execute after the server responded.
	*/
	public func saveMSISDN(msisdn: String, completion: (NSError?) -> ()) {
		installationManager.saveMsisdn(msisdn, completion: completion)
	}
	
	/**
	Explicitly tries to save installation data on the server.
	*/
	public func syncWithServer(completion: (NSError? -> Void)? = nil) {
		installationManager.syncWithServer(completion)
	}
	
	//MARK: Observing
	/**
	Registers `observer` to receive notifications for the specified key-path relative to the Installation.
	`observer` is no retained. An object that calls this method must also call either the removeObserver:forKeyPath: or removeObserver:forKeyPath:context: method if needed.
	- parameter observer: The object to register for notifications.
	- parameter keyPath: The key path, relative to the Installation, of the property to observe.
	- parameter handler: The block/closure that is called when the value of `keyPath` changes.
	*/
	public func addObserver(observer: NSObject, forKeyPath keyPath: String, handler: ObservationHandler) {
		if isKeyObservable(keyPath) {
			ManagedObjectNotificationCenter.defaultCenter.addObserver(observer, observee: installationManager.installationObject, forKeyPath: keyPath, handler: handler)
		}
	}
	
	public override func addObserver(observer: NSObject, forKeyPath keyPath: String, options: NSKeyValueObservingOptions, context: UnsafeMutablePointer<Void>) {
		addObserver(observer, forKeyPath: keyPath) { (keyPath, newValue) in
			observer.observeValueForKeyPath(keyPath, ofObject: self, change: [NSKeyValueChangeNewKey: newValue], context: context)
		}
	}
	
	public override func removeObserver(observer: NSObject, forKeyPath keyPath: String) {
		ManagedObjectNotificationCenter.defaultCenter.removeObserver(observer, observee: installationManager.installationObject, forKeyPath: keyPath)
	}
	
	public override func removeObserver(observer: NSObject, forKeyPath keyPath: String, context: UnsafeMutablePointer<Void>) {
		ManagedObjectNotificationCenter.defaultCenter.removeObserver(observer, observee: installationManager.installationObject, forKeyPath: keyPath)
	}
	
    //MARK: Internal
	convenience init(storage: MMCoreDataStorage, baseURL: String, applicationCode: String) {
		let registrationRemoteAPI = MMRemoteAPIQueue(baseURL: baseURL, applicationCode: applicationCode)
		self.init(storage: storage, registrationRemoteAPI: registrationRemoteAPI)
	}
	
	init(storage: MMCoreDataStorage, registrationRemoteAPI: MMRemoteAPIQueue) {
		self.installationManager = MMInstallationManager(storage: storage, registrationRemoteAPI: registrationRemoteAPI)
	}
	
	var registrationRemoteAPI: MMRemoteAPIQueue {
		set { installationManager.registrationRemoteAPI = newValue }
		get { return installationManager.registrationRemoteAPI }
	}
	
    var metaData: NSDictionary? {
        get { return installationManager.getValueForKey("metaData") as? NSDictionary }
        set { installationManager.setValueForKey("metaData", value: newValue) }
    }
    
	func updateDeviceToken(token: NSData, completion: (NSError? -> Void)? = nil) {
		installationManager.updateDeviceToken(token, completion: completion)
	}
	
	func save(completion: (() -> Void)? = nil) {
        installationManager.save(completion)
    }
	
    func metaForKey(key: NSCopying) -> String? {
        var result: String? = nil
        if let metaData = self.metaData {
            result = metaData[key] as? String
        }
        return result
    }
    
    func setMetaForKey(key: NSCopying, object: String) {
        if let meta = self.metaData {
            let metaData: NSMutableDictionary = meta.mutableCopy() as! NSMutableDictionary
            metaData[key] = object
            self.metaData = metaData.copy() as? NSDictionary
        } else {
            let metaData = NSMutableDictionary()
            metaData[key] = object
            self.metaData = metaData.copy() as? NSDictionary
        }
    }
    
    //MARK: private
	private func isKeyObservable(key: String) -> Bool {
		func propertiesForClass(cl: AnyClass) -> Set<String> {
			var count = UInt32()
			let classToInspect: AnyClass = cl
			let properties : UnsafeMutablePointer <objc_property_t> = class_copyPropertyList(classToInspect, &count)
			var propertyNames = Set<String>()
			let intCount = Int(count)
			for i in 0..<intCount {
				let property : objc_property_t = properties[i]
				guard let propertyName = NSString(UTF8String: property_getName(property)) as? String else {
					debugPrint("Couldn't unwrap property name for \(property)")
					break
				}
				propertyNames.insert(propertyName)
			}
			free(properties)
			return propertyNames
		}
		
		return propertiesForClass(MMInstallation.self).intersect(propertiesForClass(InstallationManagedObject.self)).contains(key)
	}
	
    private var installationManager: MMInstallationManager
	
	var badgeNumber: Int {
		get {
			let appBadge = UIApplication.sharedApplication().applicationIconBadgeNumber
			installationManager.setValueForKey("badgeNumber", value: appBadge)
			return appBadge
		}
		set {
			guard newValue > 0 else {
				return
			}
			UIApplication.sharedApplication().applicationIconBadgeNumber = newValue
			installationManager.setValueForKey("badgeNumber", value: newValue)
		}
	}
}