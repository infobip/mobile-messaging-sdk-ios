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
	var mmContext: MobileMessaging?
	var coreDataProvider: CoreDataProvider
	var inMemoryProvider: InMemoryDataProvider
	
	func persist() {
		coreDataProvider.persist()
		inMemoryProvider.persist()
	}
	
	func resetNeedToSync() {
		resolveProvider(forAttributesSet: AttributesSet.userData).resetDirtyAttribute(AttributesSet.userData)
	}

	func shouldPersistData(forAttribute attrSet: AttributesSet) -> Bool {
		return MobileMessaging.privacySettings.userDataPersistingDisabled == false || attrSet.intersection(AttributesSet.userData).isEmpty
	}
	
	func resolveProvider(forAttributesSet attrSet: AttributesSet) -> InstallationDataProvider {
		if !shouldPersistData(forAttribute: attrSet) {
			return inMemoryProvider
		}
		return coreDataProvider
	}
	
	func resolveProvider(forKey: String, attributeName: String) -> InstallationDataProvider {
		guard let attrSet = AttributesSet.withAttribute(name: attributeName) else {
			return coreDataProvider
		}
		if !shouldPersistData(forAttribute: attrSet) {
			return inMemoryProvider
		}
		return coreDataProvider
	}
	
//MARK: - Public
	public override var description: String {
		return "User:\n  Internal ID = \(String(describing: pushRegistrationId))\n    External ID = \(String(describing: externalId))\n    Email = \(String(describing: email))\n    MSISDN = \(String(describing: msisdn))\n    Custom Data = \(String(describing: customData))\n    Predefined Data = \(String(describing: predefinedData))"
	}
	
	/// Unique push registration identifier issued by server. This identifier matches one to one with APNS cloud token of the particular application installation. This identifier is only available after `MMNotificationRegistrationUpdated` event.
	public internal(set) var pushRegistrationId: String? {
		get { return resolveProvider(forAttributesSet: AttributesSet.internalUserId).getValueForKey(Attributes.internalUserId.rawValue) as? String }
		set { resolveProvider(forAttributesSet: AttributesSet.internalUserId).setValueForKey(Attributes.internalUserId.rawValue, value: newValue) }
	}
	
	/// The user's id you can provide in order to link your own unique user identifier with Mobile Messaging user id, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var externalId: String? {
		get { return resolveProvider(forAttributesSet: AttributesSet.externalUserId).getValueForKey(Attributes.externalUserId.rawValue) as? String }
		set { resolveProvider(forAttributesSet: AttributesSet.externalUserId).setValueForKey(Attributes.externalUserId.rawValue, value: newValue) }
	}
	
	/// Saves the External User Id on the server asynchronously and executes the given callback block.
	/// - parameter externalId: The id you want to link with the current user.
	/// - parameter completion: The block to execute after the server responded.
	public func save(externalId: String, completion: @escaping (NSError?) -> Void) {
		self.externalId = externalId
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
	
//MARK: - CUSTOM DATA
	
	/// Returns user's custom data. Arbitrary attributes that are related to a particular user. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var customData: [String: CustomUserDataValue]? {
		get {
			let foundationDict = resolveProvider(forAttributesSet: AttributesSet.customUserData).getValueForKey(Attributes.customUserData.rawValue) as? [String: UserDataFoundationTypes]
			return foundationDict?.customUserDataValues
		}
		set {
			let foundationValues = newValue?.userDataFoundationTypes
			resolveProvider(forAttributesSet: AttributesSet.customUserData).setValueForKey(Attributes.customUserData.rawValue, value: foundationValues)
		}
	}
	
	//MARK: Save
	
	/// Saves the user's custom data on the server asynchronously and executes the given callback block.
	/// - parameter customData: The dictionary representing data you want to link with the current user.
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
		get { return rawPredefinedData as? [String: String] }
		set { resolveProvider(forAttributesSet: AttributesSet.predefinedUserData).setValueForKey(Attributes.predefinedUserData.rawValue, value: newValue as [AnyHashable: UserDataFoundationTypes]?) }
	}
	
	/// Saves the user's attributes on the server asynchronously and executes the given callback block.
	/// - parameter predefinedData: The dictionary representing data you want to link with the current user.
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
	
	/// Tries to fetch the user data from the server.
	/// - parameter completion: The block to execute after the server responded.
	public func fetchFromServer(completion: ((NSError?) -> Void)? = nil) {
		guard let mmContext = mmContext else {
			completion?(NSError(type: MMInternalErrorType.UnknownError))
			return
		}
		MMLogDebug("[Installation management] fetch user with server")
		let op = UserDataSynchronizationOperation(fetchingOperationWithUser: self, mmContext: mmContext, finishBlock: completion)
		installationQueue.addOperation(op)
	}
	
//MARK: - Internal
	
	var rawPredefinedData: [String: Any]? {
		return resolveProvider(forAttributesSet: AttributesSet.predefinedUserData).getValueForKey(Attributes.predefinedUserData.rawValue) as? [String: Any]
	}
	
	func syncWithServer(_ completion: ((NSError?) -> Void)? = nil) {
		guard let mmContext = mmContext else {
			completion?(NSError(type: MMInternalErrorType.UnknownError))
			return
		}
		MMLogDebug("[Installation management] sync user data with server")
		let op = UserDataSynchronizationOperation(syncOperationWithUser: self, mmContext: mmContext, finishBlock: completion)
		installationQueue.addOperation(op)
	}

	func set(data object: UserDataFoundationTypes?, forKey key: String, attributeName: String) {
		resolveProvider(forKey: key, attributeName: attributeName).set(object, key: key, attribute: attributeName)
	}
	
	init(inMemoryProvider: InMemoryDataProvider, coreDataProvider: CoreDataProvider, mmContext: MobileMessaging) {
		self.inMemoryProvider = inMemoryProvider
		self.coreDataProvider = coreDataProvider
		self.mmContext = mmContext
	}
}

let installationQueue = MMOperationQueue.newSerialQueue

//MARK: -
//MARK: -

final public class MMInstallation: NSObject {
	
//MARK: - Public	
	public override var description: String {
		return "Installation:\n    Device token = \(String(describing: deviceToken))\n    Badge number = \(badgeNumber)\n"
	}
	
	/// A read-only opaque identifier assigned by APNs to a specific app on a specific device. Each app instance receives its unique token when it registers with APNs and must share this token with its provider.
	public internal(set) var deviceToken: String? {
		get { return resolveProvider(forAttributesSet: AttributesSet.deviceToken).getValueForKey(Attributes.deviceToken.rawValue) as? String }
		set { resolveProvider(forAttributesSet: AttributesSet.deviceToken).setValueForKey(Attributes.deviceToken.rawValue, value: newValue) }
	}
	
	/// Explicitly tries to sync the entire installation (registration data, system data, user data) with the server.
	public func syncInstallationWithServer(completion: ((NSError?) -> Void)? = nil) {
		guard let user = MobileMessaging.currentUser else {
			completion?(nil)
			return
		}
		MMLogDebug("[Installation management] sync installation with server")
		let newRegOp = InstallationDataSynchronizationOperation(installation: self, user: user, mmContext: mmContext, finishBlock: completion)
		installationQueue.addOperation(newRegOp)
	}
		
	/// Explicitly tries to sync the system data with the server.
	public func syncSystemDataWithServer(completion: ((NSError?) -> Void)? = nil) {
		guard let user = MobileMessaging.currentUser else {
			completion?(nil)
			return
		}
		MMLogDebug("[Installation management] send system data to server")
		let op = SystemDataSynchronizationOperation(installation: self, user: user, mmContext: mmContext, finishBlock: completion)
		installationQueue.addOperation(op)
	}
	
	/// The number currently set as the badge of the app icon in Springboard.
	///
	/// Set to 0 (zero) to hide the badge number. The default value of this property is 0.
	public var badgeNumber: Int {
		get {
			let appBadge = mmContext.application.applicationIconBadgeNumber
			resolveProvider(forAttributesSet: AttributesSet.badgeNumber).setValueForKey(Attributes.badgeNumber.rawValue, value: appBadge)
			return appBadge
		}
		set {
			mmContext.application.applicationIconBadgeNumber = newValue
			resolveProvider(forAttributesSet: AttributesSet.badgeNumber).setValueForKey(Attributes.badgeNumber.rawValue, value: newValue)
		}
	}

//MARK: Internal
	var mmContext: MobileMessaging
	var coreDataProvider: CoreDataProvider
	var inMemoryProvider: InMemoryDataProvider
	
	func resolveProvider(forAttributesSet attrSet: AttributesSet) -> InstallationDataProvider {
		if MobileMessaging.privacySettings.applicationCodePersistingDisabled == true && attrSet == AttributesSet.applicationCode {
			return inMemoryProvider
		}
		return coreDataProvider
	}
	
	func persist() {
		coreDataProvider.persist()
		inMemoryProvider.persist()
	}
	
	func resetNeedToSync() {
		resolveProvider(forAttributesSet: AttributesSet.registrationAttributes).resetDirtyAttribute(AttributesSet.registrationAttributes)
	}
	
    init(inMemoryProvider: InMemoryDataProvider, coreDataProvider: CoreDataProvider, storage: MMCoreDataStorage, mmContext: MobileMessaging, applicationCode: String? = nil) {
		
		self.mmContext = mmContext
		self.coreDataProvider = coreDataProvider
		self.inMemoryProvider = inMemoryProvider
		
		super.init()
        if applicationCode != nil {
            self.applicationCode = applicationCode
        }
	}
	
	func updateRegistrationEnabledStatus(value: Bool, completion: ((NSError?) -> Void)? = nil) {
		isPushRegistrationEnabled = value
		syncInstallationWithServer(completion: completion)
	}
	
	func updateDeviceToken(token: Data, completion: ((NSError?) -> Void)? = nil) {
		deviceToken = token.mm_toHexString
		syncInstallationWithServer(completion: completion)
	}
	
	var applicationCode: String? {
		get { return resolveProvider(forAttributesSet: AttributesSet.applicationCode).getValueForKey(Attributes.applicationCode.rawValue) as? String }
		set { resolveProvider(forAttributesSet: AttributesSet.applicationCode).setValueForKey(Attributes.applicationCode.rawValue, value: newValue) }
	}
    
//MARK: - Private
	
	var systemDataHash: Int64 {
		get { return (resolveProvider(forAttributesSet: AttributesSet.systemDataHash).getValueForKey(Attributes.systemDataHash.rawValue) as? Int64) ?? 0 }
		set { resolveProvider(forAttributesSet: AttributesSet.systemDataHash).setValueForKey(Attributes.systemDataHash.rawValue, value: newValue) }
	}
	
	var location: CLLocation? {
		get { return resolveProvider(forAttributesSet: AttributesSet.location).getValueForKey(Attributes.location.rawValue) as? CLLocation }
		set { resolveProvider(forAttributesSet: AttributesSet.location).setValueForKey(Attributes.location.rawValue, value: newValue) }
	}
	
	var isPushRegistrationEnabled: Bool {
		get { return (resolveProvider(forAttributesSet: AttributesSet.isRegistrationEnabled).getValueForKey(Attributes.registrationEnabled.rawValue) as? Bool) ?? true }
		set { resolveProvider(forAttributesSet: AttributesSet.isRegistrationEnabled).setValueForKey(Attributes.registrationEnabled.rawValue, value: newValue) }
	}
	
	var isRegistrationStatusNeedSync: Bool {
		return resolveProvider(forAttributesSet: AttributesSet.isRegistrationEnabled).isAttributeDirty(AttributesSet.isRegistrationEnabled)
	}
}
