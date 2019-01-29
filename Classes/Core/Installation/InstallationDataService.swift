//
//  InstallationDataswift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 01/11/2018.
//

import Foundation
import CoreLocation

final class InstallationDataService: DataStorageService {
	init(inMemoryProvider: InMemoryDataProvider, coreDataProvider: CoreDataProvider, mmContext: MobileMessaging, applicationCode: String) {
		super.init(inMemoryProvider: inMemoryProvider, coreDataProvider: coreDataProvider, mmContext: mmContext)
		self.applicationCode = applicationCode
	}

	override var description: String {
		return "Installation:\n\tPush Registration Id = \(pushRegistrationId.orNil)\n\tDevice token = \(deviceToken.orNil))\n\tBadge number = \(badgeNumber)\n"
	}

	func applyDataObject(_ installationData: Installation) {
		InstallationDataMapper.apply(installationData: installationData, to: self)
	}

	var dataObject: Installation? {
		guard let pushRegistrationId = self.pushRegistrationId else {
			return nil
		}
		let systemData = MobileMessaging.userAgent.systemData
		let geoEnabled = systemData.requestPayload[Consts.SystemDataKeys.geofencingServiceEnabled] as? Bool ?? false
		return Installation(applicationUserId: self.applicationUserId, appVersion: systemData.appVer, customAttributes: self.customAttributes, deviceManufacturer: systemData.deviceManufacturer, deviceModel: systemData.deviceModel, deviceName: systemData.deviceName, deviceSecure: systemData.deviceSecure, deviceTimeZone: systemData.deviceTimeZone, geoEnabled: geoEnabled, isPrimaryDevice: isPrimaryDevice, isPushRegistrationEnabled: isPushRegistrationEnabled, language: systemData.language, notificationsEnabled: systemData.notificationsEnabled, os: systemData.os, osVersion: systemData.OSVer, pushRegistrationId: pushRegistrationId, pushServiceToken: deviceToken, pushServiceType: systemData.pushServiceType, sdkVersion: systemData.SDKVersion)
	}

	var pushRegistrationId: String? {
		get { return resolveProvider(forAttributes: .pushRegistrationId).getValueForKey(Attributes.pushRegistrationId.rawValue) as? String }
		set { resolveProvider(forAttributes: .pushRegistrationId).set(value: newValue, forAttribute: Attributes.pushRegistrationId) }
	}

	var deviceToken: String? {
		get { return resolveProvider(forAttributes: .pushServiceToken).getValueForKey(Attributes.pushServiceToken.rawValue) as? String }
		set { resolveProvider(forAttributes: .pushServiceToken).set(value: newValue, forAttribute: Attributes.pushServiceToken) }
	}

	/// The number currently set as the badge of the app icon in Springboard.
	///
	/// Set to 0 (zero) to hide the badge number. The default value of this property is 0.
	var badgeNumber: Int {
		get {
			let appBadge = MobileMessaging.application.applicationIconBadgeNumber
			_ = resolveProvider(forAttributes: .badgeNumber).set(value: appBadge, forAttribute: Attributes.badgeNumber)
			return appBadge
		}
		set {
			MobileMessaging.application.applicationIconBadgeNumber = newValue
			_ = resolveProvider(forAttributes: .badgeNumber).set(value: newValue, forAttribute: Attributes.badgeNumber)
		}
	}

	var isPrimaryDevice: Bool {
		get { return (resolveProvider(forAttributes: .isPrimaryDevice).getValueForKey(Attributes.isPrimaryDevice.rawValue) as? Bool) ?? true }
		set { resolveProvider(forAttributes: .isPrimaryDevice).set(value: newValue, forAttribute: .isPrimaryDevice) }
	}

	var applicationUserId: String? {
		get { return resolveProvider(forAttributes: .applicationUserId).getValueForKey(Attributes.applicationUserId.rawValue) as? String }
		set { _ = resolveProvider(forAttributes: .applicationUserId).set(value: newValue, forAttribute: .applicationUserId)}
	}

	var isPushRegistrationEnabled: Bool {
		get { return (resolveProvider(forAttributes: .registrationEnabled).getValueForKey(Attributes.registrationEnabled.rawValue) as? Bool) ?? true }
		set { resolveProvider(forAttributes: .registrationEnabled).set(value: newValue, forAttribute: .registrationEnabled) }
	}

	var customAttributes: [String: AttributeType]? {
		get { return (resolveProvider(forAttributes: .customInstanceAttributes).getValueForKey(Attributes.customInstanceAttributes.rawValue) as? [String: AttributeType]) }
		set { resolveProvider(forAttributes: .customInstanceAttributes).set(value: newValue, forAttribute: .customInstanceAttributes) }
	}

	var applicationCode: String? {
		get { return resolveProvider(forAttributes: .applicationCode).getValueForKey(Attributes.applicationCode.rawValue) as? String }
		set { resolveProvider(forAttributes: .applicationCode).set(value: newValue, forAttribute: .applicationCode) }
	}

	var systemDataHash: Int64 {
		get { return (resolveProvider(forAttributes: .systemDataHash).getValueForKey(Attributes.systemDataHash.rawValue) as? Int64) ?? 0 }
		set { _ = resolveProvider(forAttributes: .systemDataHash).set(value: newValue, forAttribute: .systemDataHash) }
	}

	var location: CLLocation? {
		get { return resolveProvider(forAttributes: .location).getValueForKey(Attributes.location.rawValue) as? CLLocation }
		set { _ = resolveProvider(forAttributes: .location).set(value: newValue, forAttribute: .location) }
	}

	var isPrimaryDeviceNeedSync: Bool {
		return resolveProvider(forAttributes: .isPrimaryDevice).isAttributeDirty(.isPrimaryDevice)
	}

	var isRegistrationStatusNeedSync: Bool {
		return resolveProvider(forAttributes: .registrationEnabled).isAttributeDirty(.registrationEnabled)
	}

	var depersonalizeFailCounter: Int {
		get { return (resolveProvider(forAttributes: .depersonalizeFailCounter).getValueForKey(Attributes.depersonalizeFailCounter.rawValue) as? Int) ?? 0 }
		set {
			MMLogDebug("[Installation management] setting depersonalize fail counter: \(newValue) of \(DepersonalizationConsts.failuresNumberLimit)")
			_ = resolveProvider(forAttributes: .depersonalizeFailCounter).set(value: newValue, forAttribute: Attributes.depersonalizeFailCounter)
			persist()
		}
	}

	var currentDepersonalizationStatus: SuccessPending {
		get {
			if let statusValue = resolveProvider(forAttributes: .depersonalizeStatusValue).getValueForKey(Attributes.depersonalizeStatusValue.rawValue) as? Int16 {
				return SuccessPending(rawValue: Int(statusValue)) ?? .undefined
			} else {
				return .undefined
			}
		}
		set {
			switch currentDepersonalizationStatus {
			case .pending:
				switch newValue {
				case .success, .undefined:
					depersonalizeFailCounter = 0
				case .pending:
					break
				}
			case .success, .undefined:
				break
			}
			resolveProvider(forAttributes: .depersonalizeStatusValue).set(value: newValue.rawValue, forAttribute: Attributes.depersonalizeStatusValue)
		}
	}

	func customAttribute(forKey key: String) -> AttributeType? {
		var result: AttributeType? = nil
		if let customData = self.customAttributes {
			result = customData[key]
		}
		return result
	}

	func set(customAttribute value: AttributeType?, forKey key: String) {
		set(data: value ?? NSNull(), forAttribute: Attributes.customInstanceAttribute(key: key))
	}

	//

	func save(deviceToken: Data, completion: @escaping (NSError?) -> Void) {
		self.deviceToken = deviceToken.mm_toHexString
		self.persist()
		self.syncWithServer(completion)
	}


	func save(installationData: Installation, completion: @escaping (NSError?) -> Void) {
		MMLogDebug("[InstallationDataService] saving \(installationData.dictionaryRepresentation)")
		self.applyDataObject(installationData)
		self.persist()
		self.syncWithServer(completion)
	}

	func value(forAttribute attribute: Attributes) -> Any? {
		return resolveProvider(forAttributes: attribute).getValueForKey(attribute.databaseKey)
	}

	func setValue<Value: Equatable>(_ value: Value?, forAttribute attribute: Attributes) {
		resolveProvider(forAttributes: attribute).set(value: value, forAttribute: attribute)
	}

	func set(data object: AttributeType?, forAttribute att: Attributes) {
		resolveProvider(forAttributes: att).set(nestedValue: object, forAttribute: att)
	}

	var dirtyAttributesAll: AttributesSet {
		let c = resolveProvider(forAttributes: Attributes.customInstanceAttributes).dirtyAttributesSet.filter({$0.isCustomInstanceAttribute})
		let s: AttributesSet = {
			var ret: AttributesSet = AttributesSet()
			Attributes.instanceAttributesSet.forEach { (att) in
				ret = ret.union(resolveProvider(forAttributes: att).dirtyAttributesSet.intersection([att]))
			}
			return ret
		}()
		return c.union(s)
	}

	override func shouldSaveInMemory(forAttribute attr: Attributes) -> Bool {
		return attr == .applicationCode && MobileMessaging.privacySettings.applicationCodePersistingDisabled == true
	}

	func syncSystemDataWithServer(completion: @escaping ((NSError?) -> Void)) {
		MMLogDebug("[InstallationDataService] send system data to server...")
		MMLogInfo("stored hash = \(self.systemDataHash), new hash = \(MobileMessaging.userAgent.systemData.hashValue)")
		if let op = UpdateInstanceOperation(
			installation: self,
			registrationPushRegIdToUpdate: self.pushRegistrationId,
			mmContext: mmContext,
			requireResponse: false,
			finishBlock: { completion($0.error)} )
		{
			installationQueue.addOperation(op)
		} else {
			completion(nil)
		}
	}

	func fetchFromServer(completion: @escaping ((InstallationDataService, NSError?) -> Void)) {
		MMLogDebug("[InstallationDataService] fetch from server")
		if let op = FetchInstanceOperation(
			attributesSet: Attributes.instanceAttributesSet,
			installation: self,
			mmContext: mmContext,
			finishBlock: { completion(self, $0.error) })
		{
			installationQueue.addOperation(op)
		} else {
			completion(self, nil)
		}
	}

	func resetRegistration(completion: @escaping (NSError?) -> Void) {
		MMLogDebug("[InstallationDataService] resetting registration...")
		let op = RegistrationResetOperation(user: mmContext.currentUser, installation: self, apnsRegistrationManager: mmContext.apnsRegistrationManager, finishBlock: completion)
		installationQueue.addOperation(op)
	}

	func depersonalize(completion: @escaping (_ status: SuccessPending, _ error: NSError?) -> Void) {
		let op = DepersonalizeOperation(mmContext: mmContext, finishBlock: completion)
		op.queuePriority = .veryHigh
		installationQueue.addOperation(op)
	}

	// MARK: - MobileMessagingService protocol
	override func depersonalizeService(_ mmContext: MobileMessaging, completion: @escaping () -> Void) {
		MMLogDebug("[InstallationDataService] log out")
		customAttributes = nil
		persist()
		resetNeedToSync(attributesSet: Attributes.instanceAttributesSet)
		persist()
		completion()
	}

	override func syncWithServer(_ completion: @escaping (NSError?) -> Void) {
		MMLogDebug("[InstallationDataService] sync installation data with server...")

		let followingBlock: (NSError?) -> Void = { error in
			if let actualPushRegId = self.pushRegistrationId, let keychainPushRegId = self.mmContext.keychain.pushRegId, actualPushRegId != keychainPushRegId {
				let deleteExpiredInstanceOp = DeleteInstanceOperation(
					pushRegistrationId: actualPushRegId,
					expiredPushRegistrationId: keychainPushRegId,
					mmContext: self.mmContext,
					finishBlock: { completion($0.error) }
				)

				MMLogDebug("[InstallationDataService] Expired push registration id found: \(deleteExpiredInstanceOp)")
				installationQueue.addOperation(deleteExpiredInstanceOp)
			} else {
				completion(error)
			}
		}

		if let op = UpdateInstanceOperation(
			installation: self,
			registrationPushRegIdToUpdate: self.pushRegistrationId,
			mmContext: mmContext,
			requireResponse: false,
			finishBlock: { followingBlock($0.error) })
			??
			CreateInstanceOperation(
				installation: self,
				mmContext: mmContext,
				requireResponse: true,
				finishBlock: { followingBlock($0.error) })
		{
			installationQueue.addOperation(op)
		} else {
			followingBlock(nil)
		}
	}
	// MARK: }
}
