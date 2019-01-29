//
// Created by Andrey Kadochnikov on 31/10/2018.
//

import Foundation

final class UserDataService: DataStorageService {
	override var description: String {
		return "User:\n\tExternal ID = \(externalUserId.orNil)\n\tEmails = \(String(describing: emails))\n\tphones = \(String(describing: phones))\n\tCustom Attributes = \(String(describing: customAttributes))\n\tStandard Attributes = \(String(describing: standardAttributes))"
	}

	func applyDataObject(_ userData: User) {
		UserDataMapper.apply(userData: userData, to: self)
	}

	var dataObject: User {
		return User(externalUserId: self.externalUserId, firstName: self.firstName, middleName: self.middleName, lastName: self.lastName, phones: self.phones, emails: self.emails, tags: self.tags, gender: self.gender, birthday: self.birthday, customAttributes: self.customAttributes, installations: self.installations)
	}

	var externalUserId: String? {
		get { return getValueForKey(Attributes.externalUserId) as? String }
		set { set(value: newValue, forAttribute: .externalUserId) }
	}

	var firstName: String? {
		get { return getValueForKey(Attributes.firstName) as? String }
		set { set(value: newValue, forAttribute: .firstName) }
	}

	var lastName: String? {
		get { return getValueForKey(Attributes.lastName) as? String }
		set { set(value: newValue, forAttribute: .lastName) }
	}

	var middleName: String? {
		get { return getValueForKey(Attributes.middleName) as? String }
		set { set(value: newValue, forAttribute: .middleName) }
	}

	var birthday: Date? {
		get {
			if let str = getValueForKey(Attributes.birthday) as? String {
				return DateStaticFormatters.ContactsServiceDateFormatter.date(from: str)
			} else {
				return nil
			}
		}
		set { set(value: newValue != nil ?  DateStaticFormatters.ContactsServiceDateFormatter.string(from: newValue!) : nil, forAttribute: .birthday) }
	}

	var gender: Gender? {
		get {
			if let str = getValueForKey(Attributes.gender) as? String {
				return Gender.make(with: str)
			} else {
				return nil
			}
		}
		set { set(value: newValue?.name, forAttribute: .gender) }
	}

	var emails: Array<String>? {
		get { return emailsObjects?.map({$0.address}) }
		set { self.emailsObjects = newValue == nil ? nil : newValue!.map({return Email(address: $0, preferred: false)}) }
	}

	var phones: Array<String>? {
		get { return phonesObjects?.map({$0.number}) }
		set { self.phonesObjects = newValue == nil ? nil : newValue!.map({return Phone(number: $0, preferred: false)}) }
	}

	var tags: Array<String>? {
		get { return getValueForKey(Attributes.tags) as? [String] }
		set { set(value: newValue, forAttribute: .tags) }
	}

	var customAttributes: [String: AttributeType]? {
		get { return getValueForKey(Attributes.customUserAttributes) as? [String: AttributeType] }
		set { set(value: newValue, forAttribute: .customUserAttributes) }
	}

	func setInstallation(withPushRegistrationId pushRegId: String, asPrimary primary: Bool, completion: @escaping ([Installation]?, NSError?) -> Void) {
		guard let mm = MobileMessaging.sharedInstance else {
			MMLogError("[OtherInstallation] There is no Mobile Messaging instance. Aborting...")
			completion(self.installations, NSError(type: MMInternalErrorType.UnknownError))
			return
		}

		let finish: (NSError?) -> Void = { (error) in
			if error == nil {
				self.installations = self.resolveInstallationsAfterPrimaryChange(pushRegId, primary)
				self.resetNeedToSync(attributesSet: [Attributes.instances])
			}
			completion(self.installations, error)
		}

		if mm.currentInstallation.pushRegistrationId == pushRegId {
			if let installation = mm.currentInstallation.dataObject {
				installation.isPrimaryDevice = primary
				mm.currentInstallation.save(installationData: installation, completion: finish)
			}
		} else {
			guard let mm = MobileMessaging.sharedInstance else {
				MMLogError("[OtherInstallation] There is no Mobile Messaging instance. Aborting...")
				completion(self.installations, NSError(type: MMInternalErrorType.UnknownError))
				return
			}
			guard let authPushRegistrationId = mm.currentInstallation.pushRegistrationId else {
				MMLogError("[OtherInstallation] There is no registration. Finishing...")
				completion(self.installations, NSError(type: MMInternalErrorType.NoRegistration))
				return
			}
			let body = ["isPrimary": primary]
			if let request = PatchInstance(applicationCode: mm.applicationCode, authPushRegistrationId: authPushRegistrationId, refPushRegistrationId: pushRegId, body: body, returnPushServiceToken: false) {
				MobileMessaging.httpSessionManager.sendRequest(request, completion: { finish($0.error) })
			} else {
				completion(self.installations, NSError(type: MMInternalErrorType.UnknownError))
			}
		}
	}

	func depersonalizeInstallation(withPushRegistrationId pushRegId: String, completion: @escaping ([Installation]?, NSError?) -> Void) {
		guard let mm = MobileMessaging.sharedInstance else {
			MMLogError("[OtherInstallation] There is no Mobile Messaging instance. Aborting...")
			completion(self.installations, NSError(type: MMInternalErrorType.UnknownError))
			return
		}
		guard pushRegId != mm.currentInstallation.pushRegistrationId else {
			MMLogError("[OtherInstallation] Attempt to depersonalize current installation with inappropriate API. Aborting...")
			completion(self.installations, NSError(type: MMInternalErrorType.CantLogoutCurrentRegistration))
			return
		}
		guard let authPushRegistrationId = mm.currentInstallation.pushRegistrationId else {
			MMLogError("[OtherInstallation] There is no registration. Finishing...")
			completion(self.installations, NSError(type: MMInternalErrorType.NoRegistration))
			return
		}

		let request = PostDepersonalize(applicationCode: mm.applicationCode, pushRegistrationId: authPushRegistrationId, pushRegistrationIdToDepersonalize: pushRegId)
		MobileMessaging.httpSessionManager.sendRequest(request) { result in
			if result.error == nil {
				self.installations = self.resolveInstallationsAfterLogout(pushRegId)
				self.resetNeedToSync(attributesSet: [Attributes.instances])
			}
			completion(self.installations, result.error)
		}
	}

	func fetchInstallations(completion: @escaping ([Installation]?, NSError?) -> Void) {
		fetchFromServer { (user, error) in
			completion(user.installations, error)
		}
	}

	func customAttribute(forKey key: String) -> AttributeType? {
		var result: AttributeType? = nil
		if let customUserData = self.customAttributes {
			result = customUserData[key]
		}
		return result
	}

	var preferredEmail: Email? {
		get { return emailsObjects?.first(where: {$0.preferred == true}) }
		set { self.emailsObjects = resetPreferred(newValue: newValue, currentValues: self.emailsObjects) }
	}

	var preferredGsm: Phone? {
		get { return phonesObjects?.first(where: {$0.preferred == true}) }
		set { self.phonesObjects = resetPreferred(newValue: newValue, currentValues: self.phonesObjects) }
	}

	var emailsObjects: Array<Email>? {
		get { return getValueForKey(Attributes.emails) as? Array<Email> }
		set { set(value: newValue, forAttribute: .emails) }
	}

	var phonesObjects: Array<Phone>? {
		get { return getValueForKey(Attributes.phones) as? Array<Phone> }
		set { set(value: newValue, forAttribute: .phones) }
	}

	var installations: Array<Installation>? {
		get { return getValueForKey(Attributes.instances) as? [Installation] }
		set { set(value: newValue, forAttribute: .instances) }
	}

	func save(userData: User, completion: @escaping (NSError?) -> Void) {
		MMLogDebug("[UserDataService] saving \(userData.dictionaryRepresentation)")
		applyDataObject(userData)
		persist()
		syncWithServer(completion)
	}

	var isChanged: Bool {
		return !coreDataProvider.installationObject.changedValues().isEmpty
	}

	var dirtyAttributesAll: AttributesSet {
		let c = resolveProvider(forAttributes: Attributes.customUserAttributes).dirtyAttributesSet.filter({$0.isCustomUserAttribute})
		let s: AttributesSet = {
			var ret: AttributesSet = AttributesSet()
			Attributes.standardAttributesSet.forEach { (att) in
				ret = ret.union(resolveProvider(forAttributes: att).dirtyAttributesSet.intersection([att]))
			}
			return ret
		}()
		return c.union(s)
	}

	func getValueForKey(_ attr: Attributes) -> Any? {
		return resolveProvider(forAttributes: attr).getValueForKey(attr.databaseKey)
	}

	var standardAttributes: [String: Any]? {
		get {
			var ret: [String: Any] = [:]
			Attributes.standardAttributesSet.forEach { (att) in
				ret[att.databaseKey] = getValueForKey(att)
			}
			return ret.nilIfEmpty
		}
		set {
			if let newValue = newValue {
				newValue.forEach({ (key, value) in
					if let att = Attributes.fromString(key), let value = value as? AnyHashable {
						set(value: value, forAttribute: att)
					}
				})
			} else {
				Attributes.standardAttributesSet.forEach { att in
					set(value: nil, forAttribute: att)
				}
			}
		}
	}

	func set(customAttribute value: AttributeType?, forKey key: String) {
		let att = Attributes.customUserAttribute(key: key)
		resolveProvider(forAttributes: att).set(nestedValue: value ?? NSNull(), forAttribute: att)
	}

	func set(value: Any?, forAttribute attribute: Attributes) {
		resolveProvider(forAttributes: attribute).set(value: value, forAttribute: attribute)
	}

	func resolveInstallationsAfterPrimaryChange(_ pushRegId: String, _ isPrimary: Bool) -> [Installation]? {
		let ret = self.installations
		if let idx = ret?.firstIndex(where: { $0.isPrimaryDevice == true }) {
			ret?[idx].isPrimaryDevice = false
		}
		if let idx = ret?.firstIndex(where: { $0.pushRegistrationId == pushRegId }) {
			ret?[idx].isPrimaryDevice = isPrimary
		}
		return ret
	}

	func resolveInstallationsAfterLogout(_ pushRegId: String) -> [Installation]? {
		var ret = self.installations
		if let idx = ret?.firstIndex(where: { $0.pushRegistrationId == pushRegId }) {
			ret?.remove(at: idx)
		}
		return ret
	}

	func personalize(forceDepersonalize: Bool, userIdentity: UserIdentity, userAttributes: UserAttributes?, completion: @escaping (NSError?) -> Void) {
		applyDataObject(User(userIdentity: userIdentity, userAttributes: userAttributes))
		persist()

		if let op = PersonalizeOperation(
			forceDepersonalize: forceDepersonalize,
			userIdentity: userIdentity,
			userAttributes: userAttributes,
			mmContext: mmContext,
			finishBlock: { completion($0.error) })
		{
			op.queuePriority = .veryHigh
			installationQueue.addOperation(op)
		} else {
			completion(nil)
		}
	}

	func cleanup() {
		standardAttributes = nil
		customAttributes = nil
	}

	override func shouldSaveInMemory(forAttribute attr: Attributes) -> Bool {
		return MobileMessaging.privacySettings.userDataPersistingDisabled == true && Attributes.userDataAttributesSet.intersectsWith([attr])
	}
	
	func fetchFromServer(completion: @escaping (UserDataService, NSError?) -> Void) {
		MMLogDebug("[UserDataService] fetch from server")
		if let op = FetchUserOperation(
			attributesSet: Attributes.userDataAttributesSet,
			user: self,
			mmContext: mmContext,
			finishBlock: { completion(self, $0.error) })
		{
			installationQueue.addOperation(op)
		} else {
			completion(self, nil)
		}
	}
	

	// MARK: - MobileMessagingService protocol {
	override func depersonalizeService(_ mmContext: MobileMessaging, completion: @escaping () -> Void) {
		MMLogDebug("[UserDataService] log out")
		cleanup()
		persist()
		resetNeedToSync(attributesSet: Attributes.userDataAttributesSet)
		persist()
		completion()
	}

	override func syncWithServer(_ completion: @escaping (NSError?) -> Void) {
		MMLogDebug("[UserDataService] sync user data with server")

		if let op = UpdateUserOperation(
			attributesSet: dirtyAttributesAll,
			currentUser: self,
			mmContext: mmContext,
			requireResponse: false,
			finishBlock: { completion($0.error) })
		{
			installationQueue.addOperation(op)
		} else {
			completion(nil)
		}
	}
	// MARK: }
}
