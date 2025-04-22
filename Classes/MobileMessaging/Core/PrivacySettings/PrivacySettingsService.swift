//
//  PrivacySettingsService.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 16.04.2025.
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
            selector: #selector(handleAppCodePersistingUpdated(_:)),
            name: NSNotification.Name(rawValue: MMConsts.Notifications.PrivacySettings.appCodePersistingUpdated),
            object: nil)

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
    }
    
    @objc func handleAppCodePersistingUpdated(_ notification: Notification) {
        cleanupAppCode()
    }
    
    @objc func handleUserDataPersistingUpdated(_ notification: Notification) {
        cleanupUserData()
    }
    
    @objc func handleInstallationDataPersistingUpdated(_ notification: Notification) {
        cleanupInstallationData()
    }
    
    private func evaluateCurrentPrivacySettings() {
        cleanupAppCode()
        cleanupUserData()
        cleanupInstallationData()
    }
    
    private func cleanupAppCode() {
        guard MobileMessaging.privacySettings.applicationCodePersistingDisabled else {
            return
        }
        let dataCurrent = mmContext.internalData()
        dataCurrent.removeSensitiveData()
        dataCurrent.archiveCurrent()
    }
    
    private func cleanupUserData() {
        guard MobileMessaging.privacySettings.userDataPersistingDisabled else {
            return
        }
        let currentUser = mmContext.currentUser()
        currentUser.removeSensitiveData()
        currentUser.archiveCurrent()
        
        let dirtyUser = mmContext.dirtyUser()
        dirtyUser.removeSensitiveData()
        dirtyUser.archiveDirty()
    }
    
    private func cleanupInstallationData() {
        guard MobileMessaging.privacySettings.installationDataPersistingDisabled else {
            return
        }
        let currentInstallation = mmContext.currentInstallation()
        currentInstallation.removeSensitiveData()
        currentInstallation.archiveCurrent()
        
        let dirtyInstallation = mmContext.dirtyInstallation()
        dirtyInstallation.removeSensitiveData()
        dirtyInstallation.archiveDirty()
    }
}
