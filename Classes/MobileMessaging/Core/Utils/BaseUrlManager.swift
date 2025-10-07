// 
//  BaseUrlManager.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
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
        guard mmContext.remoteAPIBaseURL == Consts.APIValues.prodDynamicBaseURLString,
        itsTimeToCheckBaseUrl() else {
            // injected base URLs need to be respected. Otherwise, check for dynamic URL if needed
            completion()
            return
        }
        logDebug("Checking actual base URL...")
        mmContext.remoteApiProvider.getBaseUrl(applicationCode: mmContext.applicationCode, queue: mmContext.queue) {
            self.handleResult(result: $0)
            completion()
        }
    }
    
    public override func mobileMessagingWillStart(_ completion: @escaping () -> Void) {
        start({ _ in completion() })
    }

    public override func mobileMessagingDidStart(_ completion: @escaping () -> Void) {
        checkBaseUrl({ completion() })
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
