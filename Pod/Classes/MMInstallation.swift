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

@available(*, deprecated, message: "Use `CustomUserDataValue` class to wrap the custom user data value.")
@objc public protocol UserDataSupportedTypes: AnyObject {}
@available(*, deprecated)
extension NSDate: UserDataSupportedTypes {}
@available(*, deprecated)
extension NSString: UserDataSupportedTypes {}
@available(*, deprecated)
extension NSNumber: UserDataSupportedTypes {}
@available(*, deprecated)
extension NSNull: UserDataSupportedTypes {}

@objc public enum MMUserGenderValues: Int {
	case Female
	case Male
	
	var name: String {
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
		get { return predefinedData(forKey: MMUserPredefinedDataKeys.Email) }
		set { set(predefinedData: newValue, forKey: MMUserPredefinedDataKeys.Email) }
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
		get { return predefinedData(forKey: MMUserPredefinedDataKeys.MSISDN) }
		set { set(predefinedData: newValue, forKey: MMUserPredefinedDataKeys.MSISDN) }
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
	public var customData: [String: CustomUserDataValue]? {
		get {
			let foundationDict = installationManager.getValueForKey("customUserData") as? [String: UserDataFoundationTypes]
			return foundationDict?.customUserDataValues
		}
		set {
			let foundationValues = newValue?.userDataFoundationTypes
			installationManager.setValueForKey("customUserData", value: foundationValues)
		}
	}
	
	//MARK: Save
	
	/// Saves the user's custom data on the server asynchronously and executes the given callback block.
	/// - parameter data: The dictionary representing data you want to link with the current user.
	/// - parameter completion: The block to execute after the server responded.
	public func save(customData: [String: CustomUserDataValue], completion: @escaping (NSError?) -> Void) {
		self.customData = customData
		save(completion)
	}
	
	//MARK: Getter
	
	/// Returns the custom data value associated with a given key.
	/// - parameter key: The key for which to return the corresponding value.
	public func customData(forKey key: String) -> CustomUserDataValue? {
		var result: CustomUserDataValue? = nil
		if let customUserData = self.customData {
			result = customUserData[key]
		}
		return result
	}
	
	//MARK: Setter for key
	
	/// Sets the custom data value for a given key. To save data, call `save(completion:)` method of `MMUser` object.
	/// - parameter key: The key for `object`.
	/// - parameter object: The object for `key`. Pass `object` as either `nil` or `NSNull()` in order to remove the key-value pair on the server.
	public func set(customData object: CustomUserDataValue?, forKey key: String) {
		set(data: object?.dataValue ?? NSNull(), forKey: key, attributeName: "customUserData")
	}
	
	//MARK: Save for key
	
	/// Sets the custom data value for a given key, immediately sends changes to the server asynchronously and executes the given callback block.
	/// - parameter key: The key for `object`.
	/// - parameter object: The object for `key`. Pass `object` as either `nil` or `NSNull()` in order to remove the key-value pair on the server.
	/// - parameter completion: The block to execute after the server responded.
	public func save(customData object: CustomUserDataValue?, forKey key: String, completion: @escaping (NSError?) -> Void) {
		self.set(customData: object, forKey: key)
		save(completion)
	}
	
//MARK: - PREDEFINED DATA
	
	/// Returns user's predefined attributes (all possible attributes are described in the `MMUserPredefinedDataKeys` enum). Predefined attributes that are related to a particular user. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var predefinedData: [String: String]? {
		get { return installationManager.getValueForKey("predefinedUserData") as? [String: String] }
		set { installationManager.setValueForKey("predefinedUserData", value: newValue as [AnyHashable: UserDataFoundationTypes]?) }
	}
	
	/// Saves the user's attributes on the server asynchronously and executes the given callback block.
	/// - parameter data: The dictionary representing data you want to link with the current user.
	/// - parameter completion: The block to execute after the server responded.
	public func save(predefinedData: [String: String], completion: @escaping (NSError?) -> Void) {
		self.predefinedData = predefinedData
		save(completion)
	}
	
	/// Returns the user's attribute value associated with a given key.
	/// - parameter key: The key of type `MMUserPredefinedDataKeys` for which to return the corresponding value.
	public func predefinedData(forKey key: MMUserPredefinedDataKeys) -> String? {
		var result: String? = nil
		if let predefinedData = self.predefinedData {
			result = predefinedData[key.name]
		}
		return result
	}
	
	/// Sets the user's attribute value for a given key. To save data, call `save(completion:)` method of `MMUser` object.
	/// - parameter key: The key of type `MMUserPredefinedDataKeys` for `object`.
	/// - parameter object: The object for `key`. Pass `object` as either `nil` or `NSNull()` in order to remove the key-value pair on the server.
	public func set(predefinedData object: String?, forKey key: MMUserPredefinedDataKeys) {
		set(data: object as UserDataFoundationTypes?, forKey: key.name, attributeName: "predefinedUserData")
	}
	
	/// Sets the user's attribute value for a given key, immediately sends changes to the server asynchronously and executes the given callback block.
	/// - parameter key: The key for `object`.
	/// - parameter object: The object for `key` of type `MMUserPredefinedDataKeys`. Pass `object` as either `nil` or `NSNull()` in order to remove the key-value pair on the server.
	/// - parameter completion: The block to execute after the server responded.
	public func save(predefinedData object: String?, forKey key: MMUserPredefinedDataKeys, completion: @escaping (NSError?) -> Void) {
		set(predefinedData: object, forKey: key)
		save(completion)
	}
	
	/// Explicitly tries to save all user data on the server.
	/// - parameter completion: The block to execute after the server responded.
	public func save(_ completion: ((NSError?) -> Void)? = nil) {
		syncWithServer(completion)
	}
	
	/// Explicitly resets the unsaved user data.
	public func reset() {
		installationManager.resetContext()
	}
	
	/// Tries to fetch the user data from the server.
	/// - parameter completion: The block to execute after the server responded.
	public func fetchFromServer(completion: ((NSError?) -> Void)? = nil) {
		installationManager.fetchUserWithServer(completion)
	}
	
//MARK: - Internal
	
	func syncWithServer(_ completion: ((NSError?) -> Void)? = nil) {
		installationManager.syncUserDataWithServer(completion)
	}

	func set(data object: UserDataFoundationTypes?, forKey key: String, attributeName: String) {
		installationManager.set(object, key: key, attribute: attributeName)
	}
	
	init(installation: MMInstallation) {
		installationManager = installation.installationManager
	}
	
	func persist() {
		installationManager.registrationQueue.addOperation {
			self.installationManager.storageContext.MM_saveToPersistentStoreAndWait()
		}
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
	
	/// Explicitly tries to sync the entire installation (registration data, system data, user data) with the server.
	public func syncInstallationWithServer(completion: ((NSError?) -> Void)? = nil) {
		installationManager.syncInstallationWithServer(completion)
	}
		
	/// Explicitly tries to sync the system data with the server.
	public func syncSystemDataWithServer(completion: ((NSError?) -> Void)? = nil) {
		installationManager.sendSystemDataToServer(completion)
	}
	
	/// The number currently set as the badge of the app icon in Springboard.
	///
	/// Set to 0 (zero) to hide the badge number. The default value of this property is 0.
	public var badgeNumber: Int {
		get {
			let appBadge = mmContext?.application.applicationIconBadgeNumber ?? 0
			installationManager.setValueForKey("badgeNumber", value: appBadge)
			return appBadge
		}
		set {
			mmContext?.application.applicationIconBadgeNumber = newValue
			installationManager.setValueForKey("badgeNumber", value: newValue)
		}
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
	let mmContext: MobileMessaging?
    init(storage: MMCoreDataStorage, mmContext: MobileMessaging?, applicationCode: String? = nil) {
		self.installationManager = MMInstallationManager(storage: storage, mmContext: mmContext)
		self.mmContext = mmContext
        super.init()
        if applicationCode != nil {
            self.applicationCode = applicationCode
        }
	}
	
	func updateRegistrationEnabledStatus(value: Bool, completion: ((NSError?) -> Void)? = nil) {
		installationManager.updateRegistrationEnabledStatus(withValue: value, completion: completion)
	}
	
	func updateDeviceToken(token: Data, completion: ((NSError?) -> Void)? = nil) {
		installationManager.updateDeviceToken(token: token, completion: completion)
	}
	
	class func applicationCodeChanged(storage: MMCoreDataStorage, newApplicationCode: String) -> Bool {
		let im = MMInstallationManager(storage: storage, mmContext: nil)
		let currentApplicationCode = im.getValueForKey("applicationCode") as? String
        return currentApplicationCode != nil && currentApplicationCode != newApplicationCode
	}
	
	var applicationCode: String? {
		get { return installationManager.getValueForKey("applicationCode") as? String }
		set { installationManager.setValueForKey("applicationCode", value: newValue) }
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
