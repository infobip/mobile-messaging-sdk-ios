//
//  MMInstallation.swift
//  MobileMessaging
//
//  Created by Andrey K. on 17/02/16.
//  
//

import CoreData
import Foundation

@objc public protocol UserDataSupportedTypes: AnyObject {}
extension NSString: UserDataSupportedTypes {}
extension NSNumber: UserDataSupportedTypes {}
extension NSNull: UserDataSupportedTypes {}

@objc public enum MMUserGenderValues: Int {
	case Female
	case Male
	
	func name() -> String {
		switch self {
		case .Female : return "F"
		case .Male : return "M"
		}
	}
}

@objc public enum MMUserPredefinedDataKeys: Int {
	case MSISDN
	case FirstName
	case LastName
	case Gender
	case Birthdate
	case Email
	
	var name: String {
		switch self {
		case .MSISDN : return "msisdn"
		case .FirstName : return "firstName"
		case .LastName : return "lastName"
		case .Gender : return "gender"
		case .Birthdate : return "birthdate"
		case .Email : return "email"
		}
	}
}

final public class MMUser: NSObject {
//MARK: Public
	public override var description: String {
		return "User:\n  Internal ID = \(internalId)\n    External ID = \(externalId)\n    Email = \(email)\n    MSISDN = \(msisdn)\n    Custom Data = \(customData)"
	}
	
	/**
	A read-only identifier provided by server to uniquely identify the current app instance on a specific device.
	*/
	public internal(set) var internalId: String? {
		get { return installationManager.getValueForKey("internalUserId") as? String }
		set { installationManager.setValueForKey("internalUserId", value: newValue) }
	}
	
	/**
	The user's id you can provide in order to link your own unique user identifier with Mobile Messaging user id, so that you will be able to send personalised targeted messages to exact user and other nice features.
	*/
	public internal(set) var externalId: String? {
		get { return installationManager.getValueForKey("externalUserId") as? String }
		set { installationManager.setValueForKey("externalUserId", value: newValue) }
	}
	
	/**
	Saves the External User Id on the server asynchronously and executes the given callback block.
	- parameter id: The id you want to link with the current user.
	- parameter completion: The block to execute after the server responded.
	*/
	public func saveExternalId(id: String, completion: NSError? -> Void) {
		self.externalId = id
		save(completion)
	}
	
	/**
	The user's email address. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	*/
	public var email: String? {
		get { return predefinedDataForKey(MMUserPredefinedDataKeys.Email) as? String }
		set { setPredefinedDataForKey(MMUserPredefinedDataKeys.Email, object: newValue as NSString?) }
	}
	
	/**
	Saves the email on the server asynchronously and executes the given callback block.
	- parameter email: The email you want to link with the current user.
	- parameter completion: The block to execute after the server responded.
	*/
	public func saveEmail(email: String, completion: NSError? -> Void) {
		self.email = email
		save(completion)
	}
	
	/**
	A user's MSISDN. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	*/
	public var msisdn: String? {
		get { return predefinedDataForKey(MMUserPredefinedDataKeys.MSISDN) as? String }
		set { setPredefinedDataForKey(MMUserPredefinedDataKeys.MSISDN, object: newValue as NSString?) }
	}
	
	/**
	Saves the MSISDN on the server asynchronously and executes the given callback block.
	- parameter msisdn: The MSISDN you want to link with the current user.
	- parameter completion: The block to execute after the server responded.
	*/
	public func saveMSISDN(msisdn: String, completion: NSError? -> Void) {
		self.msisdn = msisdn
		save(completion)
	}
	
	
	// ================================= CUSTOM DATA =================================
	/**
	Returns user's custom data. Arbitrary attributes that are related to a particular user. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	*/
	public var customData: [String: UserDataSupportedTypes]? {
		get { return installationManager.getValueForKey("customUserData") as? [String: UserDataSupportedTypes] }
		set { installationManager.setValueForKey("customUserData", value: newValue) }
	}
	
	/**
	Saves the user's custom data on the server asynchronously and executes the given callback block.
	- parameter data: The dictionary representing data you want to link with the current user.
	- parameter completion: The block to execute after the server responded.
	*/
	public func saveCustomData(data: [String: UserDataSupportedTypes], completion: NSError? -> Void) {
		self.customData = data
		save(completion)
	}
	
	/**
	Returns the custom data value associated with a given key.
	- parameter key: The key for which to return the corresponding value.
	*/
	public func customDataForKey(key: String) -> UserDataSupportedTypes? {
		var result: UserDataSupportedTypes? = nil
		if let customUserData = self.customData {
			result = customUserData[key]
		}
		return result is NSNull ? nil : result
	}
	
	/**
	Sets the custom data value for a given key. To save data, call `save(completion:)` method of `MMUser` object.
	- parameter key: The key for `object`.
	- parameter object: The object for `key`. Pass `object` as either `nil` or `NSNull()` in order to remove the key-value pair on the server.
	*/
	public func setCustomDataForKey(key: String, object: UserDataSupportedTypes?) {
		setDataForKey(key, attributeName: "customUserData", object: object)
	}
	
	/**
	Sets the custom data value for a given key, immediately sends changes to the server asynchronously and executes the given callback block.
	- parameter key: The key for `object`.
	- parameter object: The object for `key`. Pass `object` as either `nil` or `NSNull()` in order to remove the key-value pair on the server.
	- parameter completion: The block to execute after the server responded.
	*/
	public func saveCustomDataForKey(key: String, object: UserDataSupportedTypes?, completion: NSError? -> Void) {
		self.setCustomDataForKey(key, object: object)
		save(completion)
	}
	
	
	// ================================= PREDEFINED DATA =================================
	/**
	Returns user's predefined attributes (all possible attributes are described in the `MMUserPredefinedDataKeys` enum). Predefined attributes that are related to a particular user. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	*/
	public var predefinedData: [String: UserDataSupportedTypes]? {
		get { return installationManager.getValueForKey("predefinedUserData") as? [String: UserDataSupportedTypes] }
		set { installationManager.setValueForKey("predefinedUserData", value: newValue) }
	}
	
	/**
	Saves the user's attributes on the server asynchronously and executes the given callback block.
	- parameter data: The dictionary representing data you want to link with the current user.
	- parameter completion: The block to execute after the server responded.
	*/
	public func savePredefinedData(data: [String: UserDataSupportedTypes], completion: NSError? -> Void) {
		self.predefinedData = data
		save(completion)
	}
	
	/**
	Returns the user's attribute value associated with a given key.
	- parameter key: The key of type `MMUserPredefinedDataKeys` for which to return the corresponding value.
	*/
	public func predefinedDataForKey(key: MMUserPredefinedDataKeys) -> UserDataSupportedTypes? {
		var result: UserDataSupportedTypes? = nil
		if let predefinedData = self.predefinedData {
			result = predefinedData[key.name]
		}
		return result is NSNull ? nil : result
	}
	
	/**
	Sets the user's attribute value for a given key. To save data, call `save(completion:)` method of `MMUser` object.
	- parameter key: The key of type `MMUserPredefinedDataKeys` for `object`.
	- parameter object: The object for `key`. Pass `object` as either `nil` or `NSNull()` in order to remove the key-value pair on the server.
	*/
	public func setPredefinedDataForKey(key: MMUserPredefinedDataKeys, object: UserDataSupportedTypes?) {
		setDataForKey(key.name, attributeName: "predefinedUserData", object: object)
	}
	
	/**
	Sets the user's attribute value for a given key, immediately sends changes to the server asynchronously and executes the given callback block.
	- parameter key: The key for `object`.
	- parameter object: The object for `key` of type `MMUserPredefinedDataKeys`. Pass `object` as either `nil` or `NSNull()` in order to remove the key-value pair on the server.
	- parameter completion: The block to execute after the server responded.
	*/
	public func savePredefinedDataForKey(key: MMUserPredefinedDataKeys, object: UserDataSupportedTypes?, completion: NSError? -> Void) {
		setPredefinedDataForKey(key, object: object)
		save(completion)
	}
	
	/**
	Explicitly tries to save all user data on the server.
	*/
	public func save(completion: (NSError? -> Void)? = nil) {
		syncWithServerIfNeeded(completion, force: false)
	}
	
	/**
	Tries to sync all local user data with server user data.
	*/
	public func syncWithServer(completion: (NSError? -> Void)? = nil) {
		syncWithServerIfNeeded(completion, force: true)
	}
	
//MARK: Internal
	func setDataForKey(key: String, attributeName: String, object: UserDataSupportedTypes?) {
		if let dictionaryValue = installationManager.getValueForKey(attributeName) as? [String: AnyObject] {
			var updatedDictionaryValue = dictionaryValue
			updatedDictionaryValue[key] = object ?? NSNull()
			installationManager.setValueForKey(attributeName, value: updatedDictionaryValue)
		} else {
			installationManager.setValueForKey(attributeName, value: [key: object ?? NSNull()])
		}
	}
	
	init(installation: MMInstallation) {
		self.installationManager = installation.installationManager
	}
	
	func syncWithServerIfNeeded(completion: (NSError? -> Void)? = nil, force: Bool) {
		installationManager.syncUserWithServer(completion, force: force)
	}
	
	public func persist() {
		installationManager.storageContext.MM_saveToPersistentStoreAndWait()
	}
	
	private let installationManager: MMInstallationManager
}


final public class MMInstallation: NSObject {
	
	deinit {
		ManagedObjectNotificationCenter.defaultCenter.removeAllObservers()
	}
	
	//MARK: Public
	public override var description: String {
		return "Installation:\n    Device token = \(deviceToken)\n    Badge number = \(badgeNumber)\n"
	}
	
	/**
	A read-only opaque identifier assigned by APNs to a specific app on a specific device. Each app instance receives its unique token when it registers with APNs and must share this token with its provider.
	*/
	public internal(set) var deviceToken: String? {
		get { return installationManager.getValueForKey("deviceToken") as? String }
		set { installationManager.setValueForKey("deviceToken", value: newValue) }
	}
	
	/**
	Explicitly tries to save installation data on the server.
	*/
	public func syncWithServer(completion: (NSError? -> Void)? = nil) {
		installationManager.syncRegistrationWithServer(completion)
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
	
	/**
	The number currently set as the badge of the app icon in Springboard.
	
	Set to 0 (zero) to hide the badge number. The default value of this property is 0.
	*/
	public var badgeNumber: Int {
		get {
			let appBadge = UIApplication.sharedApplication().applicationIconBadgeNumber
			installationManager.setValueForKey("badgeNumber", value: appBadge)
			return appBadge
		}
		set {
			UIApplication.sharedApplication().applicationIconBadgeNumber = newValue
			installationManager.setValueForKey("badgeNumber", value: newValue)
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
	
	func updateDeviceToken(token: NSData, completion: (NSError? -> Void)? = nil) {
		installationManager.updateDeviceToken(token, completion: completion)
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
	
    private let installationManager: MMInstallationManager
}