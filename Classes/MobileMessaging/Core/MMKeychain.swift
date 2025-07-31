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
    
    override init() {
        let prefix = Consts.KeychainKeys.prefix + "/" + (Bundle.main.bundleIdentifier ?? "")
        super.init(keyPrefix: prefix)
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
            set(unwrappedValue, forKey: key, withAccess: .accessibleWhenUnlockedThisDeviceOnly)
        } else {
            delete(key)
        }
    }
}
