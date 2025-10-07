// 
//  PrivacySettingsService.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

class PrivacySettingsService : MobileMessagingService {
    init(mmContext: MobileMessaging) {
        super.init(mmContext: mmContext, uniqueIdentifier: "PrivacySettingsService")
    }
    
    override func mobileMessagingWillStart(_ completion: @escaping () -> Void) {
        assert(!Thread.isMainThread)
        start({_ in completion() })
    }
    
    override func start(_ completion: @escaping (Bool) -> Void) {
        assert(!Thread.isMainThread)
        evaluateCurrentPrivacySettings()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserDataPersistingUpdated(_:)),
            name: NSNotification.Name(rawValue: MMConsts.Notifications.PrivacySettings.userDataPersistingUpdated),
            object: nil)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInstallationDataPersistingUpdated(_:)),
            name: NSNotification.Name(rawValue: MMConsts.Notifications.PrivacySettings.installationPersistingUpdated),
            object: nil)
        super.start(completion)
        logDebug("Privacy setting service started")
    }
    
    @objc func handleUserDataPersistingUpdated(_ notification: Notification) {
        logDebug("Privacy setting userDataPersistingDisabled changed, evaluating")
        cleanupUserData()
    }
    
    @objc func handleInstallationDataPersistingUpdated(_ notification: Notification) {
        logDebug("Privacy setting installationDataPersistingDisabled changed, evaluating")
        cleanupInstallationData()
    }
    
    private func evaluateCurrentPrivacySettings() {
        logDebug("Evaluating current privacy settings")
        cleanupUserData()
        cleanupInstallationData()
    }
    
    private func cleanupUserData() {
        guard MobileMessaging.privacySettings.userDataPersistingDisabled else {
            logDebug("userDataPersistingDisabled is false, skipping")
            return
        }
        logDebug("userDataPersistingDisabled is true, cleaning up")
        let currentUser = mmContext.currentUser()
        currentUser.removeSensitiveData()
        currentUser.archiveCurrent()
        
        let dirtyUser = mmContext.dirtyUser()
        dirtyUser.removeSensitiveData()
        dirtyUser.archiveDirty()
    }
    
    private func cleanupInstallationData() {
        guard MobileMessaging.privacySettings.installationDataPersistingDisabled else {
            logDebug("installationDataPersistingDisabled is false, skipping")
            return
        }
        logDebug("installationDataPersistingDisabled is true, cleaning up")
        let currentInstallation = mmContext.currentInstallation()
        currentInstallation.removeSensitiveData()
        currentInstallation.archiveCurrent()
        
        let dirtyInstallation = mmContext.dirtyInstallation()
        dirtyInstallation.removeSensitiveData()
        dirtyInstallation.archiveDirty()
    }
}
