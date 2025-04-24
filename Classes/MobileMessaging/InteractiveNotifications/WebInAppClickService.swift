//
//  WebInAppClickService.swift
//  MobileMessaging
//
//  Created by Luka Ilic on 16.10.2024..
//

import Foundation
import CoreData

class MMWebInAppClick {
    let clickUrl: String
    let buttonIdx: String
    
    init(clickUrl: String, buttonIdx: String) {
        self.clickUrl = clickUrl
        self.buttonIdx = buttonIdx
    }
}

class WebInAppClickService: MobileMessagingService {
    private let q: DispatchQueue
    private let webInAppClickReportingQueue: MMOperationQueue
    private let webInAppClickPersistingQueue: MMOperationQueue
    private let context: NSManagedObjectContext
    
    init(mmContext: MobileMessaging) {
        self.q = DispatchQueue(label: "web-inapp-click-service", qos: DispatchQoS.default, attributes: .concurrent, autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit, target: nil)
        self.webInAppClickReportingQueue = MMOperationQueue.newSerialQueue(underlyingQueue: q, name: "webInAppClickReportingQueue")
        self.webInAppClickPersistingQueue = MMOperationQueue.newSerialQueue(underlyingQueue: q, name: "webInAppClickPersistingQueue")
        self.context = mmContext.internalStorage.newPrivateContext()
        super.init(mmContext: mmContext, uniqueIdentifier: "WebInAppClickService")
    }
    
    func submitWebInAppClick(clickUrl: String, buttonIdx: String, completion: @escaping (NSError?) -> Void) {
        logDebug("WebInAppClickService.submitWebInAppClick()")
        guard let pushRegistrationId = mmContext.currentInstallation().pushRegistrationId else {
            completion(NSError(type: .NoRegistration))
            return
        }
        let mmWebInAppClick = MMWebInAppClick(clickUrl: clickUrl, buttonIdx: buttonIdx)
        persistWebInAppClick(mmWebInAppClick, pushRegistrationId) {
                self.scheduleWebInAppClickReport(completion: completion)
        }
    }
    
    override func start(_ completion: @escaping (Bool) -> Void) {
        super.start(completion)
    }
    
    override func mobileMessagingWillStart(_ completion: @escaping () -> Void) {
        start({_ in completion() })
    }
    
    override func appWillEnterForeground(_ completion: @escaping () -> Void) {
        scheduleWebInAppClickReport(completion: {_ in completion() })
    }
    
    private func persistWebInAppClick(_ mmWebInAppClick: MMWebInAppClick, _ pushRegistrationId: String, completion: @escaping () -> Void) {
        logDebug("Persisting webInAppClick")
        webInAppClickPersistingQueue.addOperation(WebInAppClickPersistingOperation(webInAppClick: mmWebInAppClick, pushRegId: pushRegistrationId, context: context, finishBlock: { _ in completion() }))
    }
    
    private func scheduleWebInAppClickReport(completion: @escaping ((NSError?) -> Void)) {
        self.logDebug("Scheduling webInAppClickReport...")
        self.webInAppClickReportingQueue.addOperation(WebInAppClickReportingOperation(mmContext: mmContext, context: context, finishBlock: completion))
    }
}
