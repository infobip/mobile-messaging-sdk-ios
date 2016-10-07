//
//  MMInstallation.swift
//  MobileMessaging
//
//  Created by Andrey K. on 17/02/16.
//  
//

import CoreData
import Foundation
import CoreLocation

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
	case MiddleName
	case Gender
	case Birthdate
	case Email
	case Telephone
	
	var name: String {
		switch self {
		case .MSISDN : return "msisdn"
		case .FirstName : return "firstName"
		case .LastName : return "lastName"
		case .MiddleName : return "middleName"
		case .Gender : return "gender"
		case .Birthdate : return "birthdate"
		case .Email : return "email"
		case .Telephone : return "telephone"
		}
	}
}

final public class MMUser: NSObject {
	
//MARK: - Public
	
	public override var description: String {
		return "User:\n  Internal ID = \(internalId)\n    External ID = \(externalId)\n    Email = \(email)\n    MSISDN = \(msisdn)\n    Custom Data = \(customData)"
	}
	
	/// A read-only identifier provided by server to uniquely identify the current app instance on a specific device.
	public internal(set) var internalId: String? {
		get { return installationManager.getValueForKey("internalUserId") as? String }
		set { installationManager.setValueForKey("internalUserId", value: newValue) }
	}
	
	/// The user's id you can provide in order to link your own unique user identifier with Mobile Messaging user id, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var externalId: String? {
		get { return installationManager.getValueForKey("externalUserId") as? String }
		set { installationManager.setValueForKey("externalUserId", value: newValue) }
	}
	
	/// Saves the External User Id on the server asynchronously and executes the given callback block.
	/// - parameter id: The id you want to link with the current user.
	/// - parameter completion: The block to execute after the server responded.
	public func save(externalId: String, completion: @escaping (NSError?) -> Void) {
		self.externalId = externalId
		save(completion)
	}
	
	@available(*, deprecated, renamed: "MMUser.save(externalId:completion:)")
	public func saveExternalId(id: String, completion: @escaping (NSError?) -> Void) {
		self.externalId = id
		save(completion)
	}
	
	/// The user's email address. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var email: String? {
		get { return predefinedData(forKey: MMUserPredefinedDataKeys.Email) as? String }
		set { set(predefinedData: newValue as NSString?, forKey: MMUserPredefinedDataKeys.Email) }
	}
	
	/// Saves the email on the server asynchronously and executes the given callback block.
	/// - parameter email: The email you want to link with the current user.
	/// - parameter completion: The block to execute after the server responded.
	public func save(email: String, completion: @escaping (NSError?) -> Void) {
		self.email = email
		save(completion)
	}
	
	/// A user's MSISDN. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var msisdn: String? {
		get { return predefinedData(forKey: MMUserPredefinedDataKeys.MSISDN) as? String }
		set { set(predefinedData: newValue as NSString?, forKey: MMUserPredefinedDataKeys.MSISDN) }
	}
	
	/// Saves the MSISDN on the server asynchronously and executes the given callback block.
	/// - parameter msisdn: The MSISDN you want to link with the current user.
	/// - parameter completion: The block to execute after the server responded.
	public func save(msisdn: String, completion: @escaping (NSError?) -> Void) {
		self.msisdn = msisdn
		save(completion)
	}


	@available(*, deprecated, renamed: "MMUser.save(msisdn:completion:)")
	public func saveMSISDN(msisdn: String, completion: @escaping (NSError?) -> Void) {
		save(msisdn: msisdn, completion: completion)
	}
	
//MARK: - CUSTOM DATA
	
	/// Returns user's custom data. Arbitrary attributes that are related to a particular user. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var customData: [String: UserDataSupportedTypes]? {
		get { return installationManager.getValueForKey("customUserData") as? [String: UserDataSupportedTypes] }
		set { installationManager.setValueForKey("customUserData", value: newValue) }
	}
	
	/// Saves the user's custom data on the server asynchronously and executes the given callback block.
	/// - parameter data: The dictionary representing data you want to link with the current user.
	/// - parameter completion: The block to execute after the server responded.
	public func save(customData: [String: UserDataSupportedTypes], completion: @escaping (NSError?) -> Void) {
		self.customData = customData
		save(completion)
	}
	
	@available(*, deprecated, renamed: "save(customData:completion:)")
	public func saveCustomData(data: [String: UserDataSupportedTypes], completion: @escaping (NSError?) -> Void) {
		save(customData: data, completion: completion)
	}
	
	/// Returns the custom data value associated with a given key.
	/// - parameter key: The key for which to return the corresponding value.
	public func customData(forKey key: String) -> UserDataSupportedTypes? {
		var result: UserDataSupportedTypes? = nil
		if let customUserData = self.customData {
			result = customUserData[key]
		}
		return result is NSNull ? nil : result
	}
	
	@available(*, deprecated, renamed: "customData(forKey:)")
	@nonobjc public func customDataForKey(key: String) -> UserDataSupportedTypes? {
		return customData(forKey: key)
	}
	
	/// Sets the custom data value for a given key. To save data, call `save(completion:)` method of `MMUser` object.
	/// - parameter key: The key for `object`.
	/// - parameter object: The object for `key`. Pass `object` as either `nil` or `NSNull()` in order to remove the key-value pair on the server.
	public func set(customData object: UserDataSupportedTypes?, forKey key: String) {
		set(data: object, forKey: key, attributeName: "customUserData")
	}
	
	@available(*, deprecated, renamed: "set(customData:forKey:)")
	public func setCustomDataForKey(key: String, object: UserDataSupportedTypes?) {
		set(customData: object, forKey: key)
	}
	
	/// Sets the custom data value for a given key, immediately sends changes to the server asynchronously and executes the given callback block.
	/// - parameter key: The key for `object`.
	/// - parameter object: The object for `key`. Pass `object` as either `nil` or `NSNull()` in order to remove the key-value pair on the server.
	/// - parameter completion: The block to execute after the server responded.
	public func save(customData object: UserDataSupportedTypes?, forKey key: String, completion: @escaping (NSError?) -> Void) {
		self.set(customData: object, forKey: key)
		save(completion)
	}
	
	@available(*, deprecated, renamed: "save(customData:forKey:completion:)")
	public func saveCustomDataForKey(key: String, object: UserDataSupportedTypes?, completion: @escaping (NSError?) -> Void) {
		save(customData: object, forKey: key, completion: completion)
	}
	
//MARK: - PREDEFINED DATA
	
	/// Returns user's predefined attributes (all possible attributes are described in the `MMUserPredefinedDataKeys` enum). Predefined attributes that are related to a particular user. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var predefinedData: [String: UserDataSupportedTypes]? {
		get { return installationManager.getValueForKey("predefinedUserData") as? [String: UserDataSupportedTypes] }
		set { installationManager.setValueForKey("predefinedUserData", value: newValue) }
	}
	
	/// Saves the user's attributes on the server asynchronously and executes the given callback block.
	/// - parameter data: The dictionary representing data you want to link with the current user.
	/// - parameter completion: The block to execute after the server responded.
	public func save(predefinedData: [String: UserDataSupportedTypes], completion: @escaping (NSError?) -> Void) {
		self.predefinedData = predefinedData
		save(completion)
	}
	
	@available(*, deprecated, renamed: "save(predefinedData:completion:)")
	public func savePredefinedData(data: [String: UserDataSupportedTypes], completion: @escaping (NSError?) -> Void) {
		save(predefinedData: data, completion: completion)
	}
	
	/// Returns the user's attribute value associated with a given key.
	/// - parameter key: The key of type `MMUserPredefinedDataKeys` for which to return the corresponding value.
	public func predefinedData(forKey key: MMUserPredefinedDataKeys) -> UserDataSupportedTypes? {
		var result: UserDataSupportedTypes? = nil
		if let predefinedData = self.predefinedData {
			result = predefinedData[key.name]
		}
		return result is NSNull ? nil : result
	}
	
	@available(*, deprecated, renamed: "predefinedData(forKey:)")
	@nonobjc public func predefinedDataForKey(key: MMUserPredefinedDataKeys) -> UserDataSupportedTypes? {
		return predefinedData(forKey: key)
	}
	
	/// Sets the user's attribute value for a given key. To save data, call `save(completion:)` method of `MMUser` object.
	/// - parameter key: The key of type `MMUserPredefinedDataKeys` for `object`.
	/// - parameter object: The object for `key`. Pass `object` as either `nil` or `NSNull()` in order to remove the key-value pair on the server.
	public func set(predefinedData object: UserDataSupportedTypes?, forKey key: MMUserPredefinedDataKeys) {
		set(data: object, forKey: key.name, attributeName: "predefinedUserData")
	}
	
	@available(*, deprecated, renamed: "set(predefinedData:forKey:)")
	public func setPredefinedDataForKey(key: MMUserPredefinedDataKeys, object: UserDataSupportedTypes?) {
		set(predefinedData: object, forKey: key)
	}
	
	/// Sets the user's attribute value for a given key, immediately sends changes to the server asynchronously and executes the given callback block.
	/// - parameter key: The key for `object`.
	/// - parameter object: The object for `key` of type `MMUserPredefinedDataKeys`. Pass `object` as either `nil` or `NSNull()` in order to remove the key-value pair on the server.
	/// - parameter completion: The block to execute after the server responded.
	public func save(predefinedData object: UserDataSupportedTypes?, forKey key: MMUserPredefinedDataKeys, completion: @escaping (NSError?) -> Void) {
		set(predefinedData: object, forKey: key)
		save(completion)
	}
	
	@available(*, deprecated, renamed: "save(predefinedData:forKey:completion:)")
	public func savePredefinedDataForKey(key: MMUserPredefinedDataKeys, object: UserDataSupportedTypes?, completion: @escaping (NSError?) -> Void) {
		save(predefinedData: object, forKey: key, completion: completion)
	}
	
	/// Explicitly tries to save all user data on the server.
	/// - parameter completion: The block to execute after the server responded.
	public func save(_ completion: ((NSError?) -> Void)? = nil) {
		syncWithServer(completion)
	}
	
	/// Tries to fetch the user data from the server.
	/// - parameter completion: The block to execute after the server responded.
	public func fetchFromServer(completion: ((NSError?) -> Void)? = nil) {
		installationManager.fetchUserWithServer(completion)
	}
	
//MARK: - Internal
	
	func syncWithServer(_ completion: ((NSError?) -> Void)? = nil) {
		installationManager.syncUserWithServer(completion)
	}
	
	func set(data object: UserDataSupportedTypes?, forKey key: String, attributeName: String) {
		installationManager.setValueForKey(attributeName, value: [key: object ?? NSNull()])
	}
	
	init(installation: MMInstallation) {
		self.installationManager = installation.installationManager
	}
	
	func persist() {
		installationManager.storageContext.MM_saveToPersistentStoreAndWait()
	}
	
	private let installationManager: MMInstallationManager
}

//MARK: -
//MARK: -

final public class MMInstallation: NSObject {
	
	deinit {
		ManagedObjectNotificationCenter.defaultCenter.removeAllObservers()
	}
	
//MARK: - Public
	
	public override var description: String {
		return "Installation:\n    Device token = \(deviceToken)\n    Badge number = \(badgeNumber)\n"
	}
	
	/// A read-only opaque identifier assigned by APNs to a specific app on a specific device. Each app instance receives its unique token when it registers with APNs and must share this token with its provider.
	public internal(set) var deviceToken: String? {
		get { return installationManager.getValueForKey("deviceToken") as? String }
		set { installationManager.setValueForKey("deviceToken", value: newValue) }
	}
	
	/// Explicitly tries to save installation data on the server.
	public func syncWithServer(completion: ((NSError?) -> Void)? = nil) {
		installationManager.syncRegistrationWithServer(completion)
	}
	
//MARK: - Observing

	/// Registers `observer` to receive notifications for the specified key-path relative to the Installation.
	///
	/// `observer` is no retained. An object that calls this method must also call either the removeObserver:forKeyPath: or removeObserver:forKeyPath:context: method if needed.
	/// - parameter observer: The object to register for notifications.
	/// - parameter keyPath: The key path, relative to the Installation, of the property to observe.
	/// - parameter handler: The block/closure that is called when the value of `keyPath` changes.
	public func addObserver(observer: NSObject, forKeyPath keyPath: String, handler: @escaping ObservationHandler) {
		if isKeyObservable(key: keyPath) {
			ManagedObjectNotificationCenter.defaultCenter.addObserver(observer: observer, observee: installationManager.installationObject, forKeyPath: keyPath, handler: handler)
		}
	}
	
	/// The number currently set as the badge of the app icon in Springboard.
	///
	/// Set to 0 (zero) to hide the badge number. The default value of this property is 0.
	public var badgeNumber: Int {
		get {
			let appBadge = UIApplication.shared.applicationIconBadgeNumber
			installationManager.setValueForKey("badgeNumber", value: appBadge)
			return appBadge
		}
		set {
			UIApplication.shared.applicationIconBadgeNumber = newValue
			installationManager.setValueForKey("badgeNumber", value: newValue)
		}
	}
	
	public override func addObserver(_ observer: NSObject, forKeyPath keyPath: String, options: NSKeyValueObservingOptions, context: UnsafeMutableRawPointer?) {
		addObserver(observer: observer, forKeyPath: keyPath) { (keyPath, newValue) in
			observer.observeValue(forKeyPath: keyPath, of: self, change: [NSKeyValueChangeKey.newKey: newValue], context: context)
		}
	}
	
	public override func removeObserver(_ observer: NSObject, forKeyPath keyPath: String) {
		ManagedObjectNotificationCenter.defaultCenter.removeObserver(observer: observer, observee: installationManager.installationObject, forKeyPath: keyPath)
	}
	
	public override func removeObserver(_ observer: NSObject, forKeyPath keyPath: String, context:UnsafeMutableRawPointer?) {
		ManagedObjectNotificationCenter.defaultCenter.removeObserver(observer: observer, observee: installationManager.installationObject, forKeyPath: keyPath)
	}
	

//MARK: Internal
	let installationManager: MMInstallationManager
	
	convenience init(storage: MMCoreDataStorage, baseURL: String, applicationCode: String) {
		let registrationRemoteAPI = MMRemoteAPIQueue(baseURL: baseURL, applicationCode: applicationCode)
		self.init(storage: storage, registrationRemoteAPI: registrationRemoteAPI)
	}
	
	init(storage: MMCoreDataStorage, registrationRemoteAPI: MMRemoteAPIQueue) {
		self.installationManager = MMInstallationManager(storage: storage, registrationRemoteAPI: registrationRemoteAPI)
	}
	
	func updateDeviceToken(token: Data, completion: ((NSError?) -> Void)? = nil) {
		installationManager.updateDeviceToken(token: token, completion: completion)
	}
    
//MARK: - Private
	var location: CLLocation? {
		get { return installationManager.getValueForKey("location") as? CLLocation }
		set { installationManager.setValueForKey("location", value: newValue) }
	}
	
	private func isKeyObservable(key: String) -> Bool {
		func propertiesForClass(cl: AnyClass) -> Set<String> {
			var count = UInt32()
			let classToInspect: AnyClass = cl
			let properties : UnsafeMutablePointer <objc_property_t?> = class_copyPropertyList(classToInspect, &count)
			var propertyNames = Set<String>()
			let intCount = Int(count)
			for i in 0..<intCount {
				if let property = properties[i] {
					guard let propertyName = String(utf8String: property_getName(property)) else {
						debugPrint("Couldn't unwrap property name for \(property)")
						break
					}
					propertyNames.insert(propertyName)
				}
			}
			free(properties)
			return propertyNames
		}
		
		return propertiesForClass(cl: MMInstallation.self).intersection(propertiesForClass(cl: InstallationManagedObject.self)).contains(key)
	}
}
