//
//  MMKeychain.swift
//
//  Created by okoroleva on 13.01.17.
//
//

struct KeychainKeys {
	static let prefix = "com.mobile-messaging"
	static let internalId = "internalId"
}

class MMKeychain: KeychainSwift {
	var internalId: String? {
		get {
			let internalId = get(KeychainKeys.internalId)
			MMLogDebug("[Keychain] get internalId \(String(describing: internalId))")
			return internalId
		}
		set {
			if let unwrappedValue = newValue {
				MMLogDebug("[Keychain] set internalId \(unwrappedValue)")
				set(unwrappedValue, forKey: KeychainKeys.internalId, withAccess: .accessibleWhenUnlockedThisDeviceOnly)
			}
		}
	}
	
	override init() {
		let prefix = KeychainKeys.prefix + "/" + (Bundle.main.bundleIdentifier ?? "")
		super.init(keyPrefix: prefix)
	}
	
	//MARK: private
	
	@discardableResult
	override func clear() -> Bool {
		MMLogDebug("[Keychain] clearing")
		let cleared = delete(KeychainKeys.internalId)
		if !cleared {
			MMLogError("[Keychain] clearing failure \(lastResultCode)")
		}
		return cleared
	}
}
