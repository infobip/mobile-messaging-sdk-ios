
//  MMTestCase.swift
//  MobileMessaging
//
//  Created by Andrey K. on 16/04/16.
//

import XCTest
import Foundation
import CoreData
@testable import MobileMessaging


class ApnsRegistrationManagerDisabledStub: ApnsRegistrationManager {
    override var isRegistrationHealthy: Bool {
        return true
    }
    
    override func setRegistrationIsHealthy() {
        
    }
    
    override func registerForRemoteNotifications(userInitiated: Bool) {
        
    }
    
    override init(mmContext: MobileMessaging) {
        super.init(mmContext: mmContext)
        self.readyToRegisterForNotifications = true
    }
}

class ApnsRegistrationManagerStub: ApnsRegistrationManager {
    override var isRegistrationHealthy: Bool {
        return true
    }
    
    override func setRegistrationIsHealthy() {
        
    }
    
    override init(mmContext: MobileMessaging) {
        super.init(mmContext: mmContext)
        self.readyToRegisterForNotifications = true
    }
}

class MessageHandlingDelegateMock : MMMessageHandlingDelegate {
    var didReceiveNewMessageHandler: ((MM_MTMessage) -> Void)?
    var willPresentInForegroundHandler: ((MM_MTMessage?) -> MMUserNotificationType)?
    var canPresentInForeground: ((MM_MTMessage) -> Void)?
    var didPerformActionHandler: ((MMNotificationAction, MM_MTMessage?, () -> Void) -> Void)?
    var didReceiveNewMessageInForegroundHandler: ((MM_MTMessage) -> Void)?
    var willScheduleLocalNotification: ((MM_MTMessage) -> Void)?
    
    
    func willScheduleLocalNotification(for message: MM_MTMessage) {
        willScheduleLocalNotification?(message)
    }
    
    func didReceiveNewMessage(message: MM_MTMessage) {
        didReceiveNewMessageHandler?(message)
    }
    
    func willPresentInForeground(message: MM_MTMessage?, withCompletionHandler completionHandler: @escaping (MMUserNotificationType) -> Void) {
        completionHandler(willPresentInForegroundHandler?(message) ?? MMUserNotificationType.none)
    }
    
    func canPresentInForeground(message: MM_MTMessage) {
        canPresentInForeground?(message)
    }
    
    func didPerform(action: MMNotificationAction, forMessage message: MM_MTMessage?, notificationUserInfo: [String: Any]?, completion: @escaping () -> Void) {
        didPerformActionHandler?(action, message, completion)
        completion()
    }
    
}


let testEnvironmentTimestampMillisSince1970 = 1503583689984 as Double
func apnsNormalMessagePayload(_ messageId: String) -> [AnyHashable: Any] {
    return [
        "messageId": messageId,
        "aps": ["alert": ["title": "msg_title", "body": "msg_body"], "badge": 6, "sound": "default"],
        Consts.APNSPayloadKeys.internalData: ["sendDateTime": testEnvironmentTimestampMillisSince1970, "internalKey": "internalValue"],
        Consts.APNSPayloadKeys.customPayload: ["customKey": "customValue"]
    ]
}

func sendPushes(_ preparingFunc:(String) -> [AnyHashable: Any], count: Int, receivingHandler: ([AnyHashable: Any]) -> Void) {
    for _ in 0..<count {
        let newMessageId = UUID().uuidString
        if let payload = MM_MTMessage(payload: preparingFunc(newMessageId), deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false)?.originalPayload {
            receivingHandler(payload)
        } else {
            XCTFail()
        }
    }
}


class ActiveApplicationStub: MMApplication {
    var applicationState: UIApplication.State { return .active }
    var applicationIconBadgeNumber: Int {
        get { return 0 }
        set {}
    }
    var visibleViewController: UIViewController? { return nil }
    var isRegisteredForRemoteNotifications: Bool { return true }
    func unregisterForRemoteNotifications() {}
    func registerForRemoteNotifications() {}
    var notificationEnabled: Bool { return true }
}

class DefaultApplicationStub: MMApplication {
    var registerForRemoteNotificationsStub: (() -> Void)?
    var unregisterForRemoteNotificationsStub: (() -> Void)?
    
    var applicationState: UIApplication.State { return .active }
    var applicationIconBadgeNumber: Int {
        get { return 0 }
        set {}
    }
    var visibleViewController: UIViewController? { return nil }
    var isRegisteredForRemoteNotifications: Bool { return true }
    func unregisterForRemoteNotifications() { unregisterForRemoteNotificationsStub?() }
    func registerForRemoteNotifications() { registerForRemoteNotificationsStub?() }
    var notificationEnabled: Bool { return true }
}

class InactiveApplicationStub: MMApplication {
    var applicationState: UIApplication.State { return .inactive }
    var applicationIconBadgeNumber: Int {
        get { return 0 }
        set {}
    }
    var visibleViewController: UIViewController? { return nil }
    var isRegisteredForRemoteNotifications: Bool { return true }
    func unregisterForRemoteNotifications() {}
    func registerForRemoteNotifications() {}
    var notificationEnabled: Bool { return true }
}

class UserAgentStub: MMUserAgent {
    override var language: String {return "en"}
    override var notificationsEnabled: Bool {return true}
    override var osVersion: String {return "1.0"}
    override var osName: String {return "mobile OS"}
    override var libraryVersion: String {return "1.0.0"}
    override var libraryName: String {return "MobileMessaging"}
    override var hostingAppVersion: String {return "1.0"}
    override var hostingAppName: String {return "WheatherApp"}
    override var deviceManufacturer: String {return "GoogleApple"}
    override var deviceName: String {return "iPhone Galaxy"}
    override var deviceModelName : String {return "XS"}
    override var deviceSecure: Bool {return true}
    override var deviceTimeZone: String? { return "GMT+03:30"}
}


class MMTestCase: XCTestCase {
    var mobileMessagingInstance: MobileMessaging {
        return MobileMessaging.sharedInstance!
    }
    
    var storage: MMCoreDataStorage {
        return self.mobileMessagingInstance.internalStorage
    }
    
    override func waitForExpectations(timeout: TimeInterval, handler: XCWaitCompletionHandler? = nil) {
        weak var e = expectation(description: "Queues finished")
        
        DispatchQueue.global().async { // we don't want to block main thread because queues might dispatch to it the finish blocks
            //todo: rework subservices to have single queue each one, then just waitUntilAllOperationsAreFinished for every subservice registered
            self.waitAllQueues(cancel: false)
            
            e?.fulfill()
        }
        
        super.waitForExpectations(timeout: timeout, handler: handler)
    }
    
    override func setUp() {
        super.setUp()
//        MobileMessaging.logger = MMDefaultLogger()
//        MobileMessaging.logger?.logOutput = .Console
//        MobileMessaging.logger?.logLevel = .Debug
        MobileMessaging.date = DateStub(nowStub: Date(timeIntervalSince1970: testEnvironmentTimestampMillisSince1970/1000))
        MobileMessaging.doCleanUp()
    }
    
    override func tearDown() {
        super.tearDown()
        
        waitAllQueues(cancel: true)
        MobileMessaging.sharedInstance?.doCleanupAndStop()
        MobileMessaging.privacySettings = MMPrivacySettings()
        MMGeofencingService.currentDate = nil
        MobileMessaging.timeZone = TimeZone.current
        MobileMessaging.calendar = Calendar.current
        MobileMessaging.userAgent = MMUserAgent()
    }
    
    private func waitAllQueues(cancel: Bool) {
        let queues = [MMGeofencingService.sharedInstance?.eventsHandlingQueue,
                      MobileMessaging.sharedInstance?.messageHandler.messageSyncQueue,
                      MobileMessaging.sharedInstance?.messageHandler.messageHandlingQueue,
                      installationQueue
        ]
        
        if cancel {
            queues.forEach { q in
                q?.cancelAllOperations()
            }
        }
        
        queues.forEach { q in
            q?.waitUntilAllOperationsAreFinished()
        }
    }
    
    class func nonReportedStoredMessagesCount(_ ctx: NSManagedObjectContext) -> Int {
        var count: Int = 0
        ctx.performAndWait {
            ctx.reset()
            count = MessageManagedObject.MM_countOfEntitiesWithPredicate(NSPredicate(format: "reportSent == false"), inContext: ctx)
        }
        return count
    }
    
    class func allStoredMessagesCount(_ ctx: NSManagedObjectContext) -> Int {
        var count: Int = 0
        ctx.performAndWait {
            ctx.reset()
            count = MessageManagedObject.MM_countOfEntitiesWithContext(ctx)
        }
        return count
    }
    
    class func startWithApplicationCode(_ code: String) {
        let mm = stubbedMMInstanceWithApplicationCode(code)
        mm?.doStart()
    }
    
    class func stubbedMMInstanceWithApplicationCode(_ code: String) -> MobileMessaging? {
        let mm = MobileMessaging.withApplicationCode(code, notificationType: MMUserNotificationType(options: []) , backendBaseURL: "http://url.com")!
        mm.setupApiSessionManagerStubbed()
        MobileMessaging.application = ActiveApplicationStub()
        mm.apnsRegistrationManager = ApnsRegistrationManagerStub(mmContext: mm)
        return mm
    }
    
    class func startWithCorrectApplicationCode() {
        let mm = stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)!
        mm.apnsRegistrationManager = ApnsRegistrationManagerDisabledStub(mmContext: mm)
        mm.doStart()
    }
    
    class func startWithWrongApplicationCode() {
        let mm = stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestWrongApplicationCode)!
        mm.apnsRegistrationManager = ApnsRegistrationManagerDisabledStub(mmContext: mm)
        mm.doStart()
    }
}

class MessageStorageStub: NSObject, MMMessageStorage, MMMessageStorageFinders, MMMessageStorageRemovers {
    func findNonSeenMessageIds(completion: @escaping (([String]) -> Void)) {
        completion([])
    }
    
    var messagesCountersUpdateHandler: ((Int, Int) -> Void)?
    
    func countAllMessages(completion: @escaping (Int) -> Void) {
        completion(mtMessages.count + moMessages.count)
    }
    
    func removeAllMessages(completion: @escaping ([MessageId]) -> Void) {
        mtMessages.removeAll()
        moMessages.removeAll()
        completion([])
    }
    
    func findAllMessageIds(completion: @escaping ([String]) -> Void) {
        completion(mtMessages.map({$0.messageId}))
    }
    
    func remove(withIds messageIds: [MessageId], completion: @escaping ([MessageId]) -> Void) {
        completion(messageIds)
    }
    
    func remove(withQuery query: MMQuery, completion: @escaping ([MessageId]) -> Void) {
        completion([])
    }
    
    func findAllMessages(completion: @escaping FetchResultBlock) {
        completion(mtMessages + moMessages)
    }
    
    func findMessages(withIds messageIds: [MessageId], completion: @escaping FetchResultBlock) {
        completion((mtMessages + moMessages).filter({ messageIds.contains($0.messageId) }))
    }
    
    func findMessages(withQuery query: MMQuery, completion: @escaping FetchResultBlock) {
        completion((mtMessages + moMessages).filter({ query.predicate?.evaluate(with: $0) ?? true }))
    }
    
    let updateMessageSentStatusHook: ((MM_MOMessageSentStatus) -> Void)?
    
    init(updateMessageSentStatusHook: ((MM_MOMessageSentStatus) -> Void)? = nil) {
        self.updateMessageSentStatusHook = updateMessageSentStatusHook
    }
    
    var queue: DispatchQueue {
        return DispatchQueue.main
    }
    var mtMessages = [MMBaseMessage]()
    var moMessages = [MMBaseMessage]()
    func insert(incoming messages: [MMBaseMessage], completion: @escaping () -> Void) {
        messages.forEach { (message) in
            self.mtMessages.append(message)
        }
        completion()
    }
    func insert(outgoing messages: [MMBaseMessage], completion: @escaping () -> Void) {
        messages.forEach { (message) in
            self.moMessages.append(message)
        }
        completion()
    }
    func findMessage(withId messageId: MessageId) -> MMBaseMessage? {
        if let idx = moMessages.index(where: { $0.messageId == messageId }) {
            return MMBaseMessage(messageId: moMessages[idx].messageId, direction: .MO, originalPayload: ["messageId": moMessages[idx].messageId], deliveryMethod: .undefined)
        } else {
            return nil
        }
    }
    func update(deliveryReportStatus isDelivered: Bool, for messageId: MessageId, completion: @escaping () -> Void) {
        completion()
    }
    func update(messageSeenStatus status: MMSeenStatus, for messageId: MessageId, completion: @escaping () -> Void) {
        completion()
    }
    func update(messageSentStatus status: MM_MOMessageSentStatus, for messageId: MessageId, completion: @escaping () -> Void) {
        updateMessageSentStatusHook?(status)
        completion()
    }
    func start() {
        
    }
    func stop() {
        
    }
}
