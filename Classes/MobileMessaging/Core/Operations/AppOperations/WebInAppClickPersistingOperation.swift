//
//  WebInAppClickPersistingOperation.swift
//  MobileMessaging
//
//  Created by Luka Ilic on 19.09.2024..
//

import Foundation
import CoreData

class WebInAppClickPersistingOperation : MMOperation {
    let context: NSManagedObjectContext
    let finishBlock: (Error?) -> Void
    let pushRegId: String
    let webInAppClick: MMWebInAppClick
    
    init(webInAppClick: MMWebInAppClick, pushRegId: String, context: NSManagedObjectContext, finishBlock: @escaping ((Error?) -> Void)) {
        self.context = context
        self.finishBlock = finishBlock
        self.pushRegId = pushRegId
        self.webInAppClick = webInAppClick
        super.init(isUserInitiated: false)
    }
    
    override func execute() {
        guard !isCancelled else {
            logDebug("cancelled WebInAppClickPersistingOperation...")
            finish()
            return
        }
        
        logVerbose("started WebInAppClickPersistingOperation...")
        
        self.context.performAndWait {
            // Check if object with same clickUrl already exists
            let predicate = NSPredicate(format: "clickUrl == %@", self.webInAppClick.clickUrl)
            let existingObject = WebInAppClickObject.MM_findFirstWithPredicate(predicate, context: self.context)
            
            if existingObject == nil {
                // Only create new object if none exists
                let newWebInAppClickObject = WebInAppClickObject.MM_createEntityInContext(context: self.context)
                newWebInAppClickObject.clickUrl = self.webInAppClick.clickUrl
                newWebInAppClickObject.pushRegistrationId = self.pushRegId
                newWebInAppClickObject.buttonIdx = self.webInAppClick.buttonIdx
                newWebInAppClickObject.attempt = 0
                self.context.MM_saveToPersistentStoreAndWait()
                logVerbose("created new WebInAppClickObject with clickUrl: \(self.webInAppClick.clickUrl)")
            } else {
                logVerbose("WebInAppClickObject with clickUrl: \(self.webInAppClick.clickUrl) already exists - skipping creation")
            }
        }
        finish()
    }
    
    override func finished(_ errors: [NSError]) {
        logVerbose("finished WebInAppClickPersistingOperation: \(errors)")
        finishBlock(errors.first)
    }
}
