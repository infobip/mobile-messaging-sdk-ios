//
//  MMKeychain.swift
//
//  Created by okoroleva on 13.01.17.
//
//

class MMKeychain: KeychainSwift, NamedLogger {
    var applicationCode: String? {
        get {
            return getWithLogging(key: Consts.KeychainKeys.appCode)
        }
        set {
            setWithLogging(key: Consts.KeychainKeys.appCode, value: newValue)
        }
    }
    var pushRegId: String? {
        get {
            return getWithLogging(key: Consts.KeychainKeys.pushRegId)
        }
        set {
            setWithLogging(key: Consts.KeychainKeys.pushRegId, value: newValue)
        }
    }
    
    init(accessGroup: String?) {
        let sharedPrefix = accessGroup == nil ? "" : "shared."
        let prefix = sharedPrefix + Consts.KeychainKeys.prefix + "/" + (Bundle.mainAppBundle.bundleIdentifier ?? "")
        super.init(keyPrefix: prefix)
        self.accessGroup = accessGroup
        if (accessGroup != nil) {
            performMigration()
        }
    }
        
    func performMigration() {
        // the set of fields should not be extended here since old keychain had only two to migrate: applicationCode and pushRegId
        if (self.applicationCode == nil || self.pushRegId == nil) {
            logDebug("Migrating data from old keychain...")
            let oldKeychain = MMKeychain(accessGroup: nil)
            if (self.applicationCode == nil && oldKeychain.applicationCode != nil) {
                self.applicationCode = oldKeychain.applicationCode
            }
            if (self.pushRegId == nil && oldKeychain.pushRegId != nil) {
                self.pushRegId = oldKeychain.pushRegId
            }
            logDebug("Clearing old keychain...")
            oldKeychain.clear()
        }
    }
    
    @discardableResult
    override func clear() -> Bool {
        logDebug("Clearing...")
        let cleared = delete(Consts.KeychainKeys.pushRegId) && delete(Consts.KeychainKeys.appCode)
        if !cleared {
            logError("Clearing failure \(lastResultCode)")
        }
        return cleared
    }
    
    //MARK: private
    private func getWithLogging(key: String) -> String? {
        let val = get(key)
        logDebug("Got \(key) \(val == nil ? "nil" : "***")")
        return val
    }
    
    private func setWithLogging(key: String, value: String?) {
        logDebug("Setting key \(key) value \(value == nil ? "nil" :  "***")")
        if let unwrappedValue = value {
            set(unwrappedValue, forKey: key, withAccess: .accessibleAfterFirstUnlockThisDeviceOnly)
        } else {
            delete(key)
        }
    }
}
