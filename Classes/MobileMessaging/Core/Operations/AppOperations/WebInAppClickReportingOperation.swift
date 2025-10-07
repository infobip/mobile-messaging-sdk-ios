// 
//  WebInAppClickReportingOperation.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import CoreData

class WebInAppClickReportingOperation: MMOperation {
    
    let mmContext: MobileMessaging
    var webInAppClickManagedObjects: [WebInAppClickObject]?
    let finishBlock: ((NSError?) -> Void)
    let context: NSManagedObjectContext
        
    init(mmContext: MobileMessaging, context: NSManagedObjectContext, finishBlock: @escaping (NSError?) -> Void) {
        self.mmContext = mmContext
        self.context = context
        self.finishBlock = finishBlock
        super.init(isUserInitiated: false)
        self.addCondition(HealthyRegistrationCondition(mmContext: mmContext))
    }
    
    override func execute() {
        guard !isCancelled else {
            logDebug("cancelled...")
            finish()
            return
        }
        guard mmContext.currentInstallation().pushRegistrationId != nil else {
            logWarn("There is no registration. Finishing...")
            finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
            return
        }
        logDebug("Started WebInAppClickReportingOperation...")
        
        context.performAndWait {
            self.webInAppClickManagedObjects = WebInAppClickObject.MM_findAllInContext(self.context)
        }
        
        guard let webInAppClickManagedObjects = self.webInAppClickManagedObjects, !webInAppClickManagedObjects.isEmpty else {
            logDebug("There are no web in-app clicks to report to the server. Finishing...")
            finish()
            return
        }
        
        logDebug("Loaded \(webInAppClickManagedObjects.count) WebInAppClickObjects from CoreData")
        
        let dispatchGroup = DispatchGroup()
        
        webInAppClickManagedObjects.forEach { webInAppClickManagedObject in
            logDebug("Click URL: \(webInAppClickManagedObject.clickUrl), Button Index: \(webInAppClickManagedObject.buttonIdx), Attempt: \(webInAppClickManagedObject.attempt)")
            dispatchGroup.enter()
            reportWebInAppClick(webInAppClick: webInAppClickManagedObject) {
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: underlyingQueue) {
            self.context.MM_saveToPersistentStoreAndWait()
            self.finish()
        }
    }
    
    private func reportWebInAppClick(webInAppClick: WebInAppClickObject, completion: @escaping () -> Void) {
        guard webInAppClick.attempt < 3 else {
            logDebug("Reached maximum number of retries for reporting of the web in-app click")
            context.performAndWait {
                context.delete(webInAppClick)
            }
            completion()
            return
        }
        
        guard let url = URL(string: webInAppClick.clickUrl) else {
            logError("Click URL cannot be parsed from \(webInAppClick.clickUrl). Finishing...")
            completion()
            return
        }
                
        mmContext.remoteApiProvider.sendWebInAppClickReport(
            url: url,
            applicationCode: mmContext.applicationCode,
            pushRegistrationId: webInAppClick.pushRegistrationId,
            buttonIdx: webInAppClick.buttonIdx,
            queue: .global()
        ) { result in
            self.handleResult(result, webInAppClick: webInAppClick)
            completion()
        }
    }
    
    override func finished(_ errors: [NSError]) {
        logDebug("Finished with errors: \(errors)")
        finishBlock(errors.first)
    }
    
    private func incrementAttemptFor(_ webInAppClick: WebInAppClickObject) {
        logDebug("Incrementing webInAppClick report attempt to \(webInAppClick.attempt + 1)")
        context.performAndWait {
            webInAppClick.attempt += 1
        }
    }
    
    private func handleResult(_ result: WebInAppClickReportResult, webInAppClick: WebInAppClickObject) {
        switch result {
        case .Success:
            logDebug("Web in-app click reported successfully")
            context.performAndWait {
                context.delete(webInAppClick)
            }
        case .Failure(_):
            incrementAttemptFor(webInAppClick)
        case .Cancel:
            incrementAttemptFor(webInAppClick)
        }
    }
}
