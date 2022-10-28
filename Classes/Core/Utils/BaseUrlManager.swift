//
//  BaseUrlManager.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 28.01.2021.
//

import Foundation

class BaseUrlManager: MobileMessagingService {
    private let defaultTimeout: Double = 60 * 60 * 24 // a day
    private var lastCheckDate : Date? {
        set {
            UserDefaults.standard.set(newValue, forKey: Consts.BaseUrlRecovery.lastCheckDateKey)
            UserDefaults.standard.synchronize()
        }
        get {
            return UserDefaults.standard.object(forKey: Consts.BaseUrlRecovery.lastCheckDateKey) as? Date
        }
    }
    
    init(mmContext: MobileMessaging) {
        super.init(mmContext: mmContext, uniqueIdentifier: "BaseUrlManager")
    }
    
    override func appWillEnterForeground(_ completion: @escaping () -> Void) {
        checkBaseUrl({ completion() })
    }
        
    func checkBaseUrl(_ completion: @escaping (() -> Void)) {
        guard itsTimeToCheckBaseUrl() else {
            completion()
            return
        }
        logDebug("Checking actual base URL...")
        mmContext.remoteApiProvider.getBaseUrl(applicationCode: mmContext.applicationCode, queue: mmContext.queue) {
            self.handleResult(result: $0)
            completion()
        }
    }
    
    func resetLastCheckDate(_ date: Date? = nil) {
        self.lastCheckDate = date
    }
    
    private func itsTimeToCheckBaseUrl() -> Bool {
        let ret = lastCheckDate == nil || (lastCheckDate?.addingTimeInterval(defaultTimeout).compare(MobileMessaging.date.now) != ComparisonResult.orderedDescending)
        if ret {
            logDebug("It's time to check the base url")
        } else {
            logDebug("It's not time to check the base url now. lastCheckDate \(String(describing: lastCheckDate)), now \(MobileMessaging.date.now), timeout \(defaultTimeout)")
        }
        return ret
    }

    private func handleResult(result: BaseUrlResult) {
        if let response = result.value {
            if let baseUrl = response.baseUrl, let newBaseUrl = URL(string: baseUrl) {
                mmContext.httpSessionManager.setNewBaseUrl(newBaseUrl: newBaseUrl)
                self.lastCheckDate = MobileMessaging.date.now
            } else {
                logDebug("No base url available")
            }
        } else {
            logError("An error occurred while trying to get base url from server: \(result.error.orNil)")
        }
    }
}
