// 
//  Example/Tests/MobileMessagingTests/ServicesSynchronizationTests.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
@testable import MobileMessaging

class UserDataServiceMock: UserDataService {
    var syncCompletion: (() -> Void)?
    override func syncWithServer(userInitiated: Bool, completion: @escaping (NSError?) -> Void) {
        syncCompletion?()
    }
}

class InstallationDataServiceMock: InstallationDataService {
    var syncCompletion: (() -> Void)?
    override func syncWithServer(userInitiated: Bool, _ completion: @escaping (NSError?) -> Void) {
        syncCompletion?()
    }
}

class NotificationInteractionServiceMock: NotificationsInteractionService {
    var syncCompletion: (() -> Void)?
    override func syncWithServer(_ completion: @escaping (NSError?) -> Void) {
        syncCompletion?()
    }
}

class MessageHandlerMock: MMMessageHandler {
    var syncCompletion: (() -> Void)?
    override func syncWithServer(userInitiated: Bool, completion: @escaping (NSError?) -> Void) {
        syncCompletion?()
    }
}

class ChatServiceMock: MMInAppChatService {
    var syncCompletion: (() -> Void)?
    override func syncWithServer(_ completion: @escaping (NSError?) -> Void) {
        syncCompletion?()
    }
}

final class ServicesSynchronizationTests: MMTestCase {
    
    // Testing that synchronization of services is done after starting SDK, because it should be like this in plugins.
    func testSyncCalledAfterStart() {
        
        weak var userDataSynced = self.expectation(description: "user data synced with server")
        weak var installationDataSynced = self.expectation(description: "installation data synced with server")
        weak var notificationInteractionSynced = self.expectation(description: "notificationInteraction synced with server")
        weak var messagesSynced = self.expectation(description: "messages synced with server")
        weak var chatSynced = self.expectation(description: "chat synced with server")
        
        let mm = ServicesSynchronizationTests.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)!

        let userServiceMock = UserDataServiceMock(mmContext: mm)
        userServiceMock.syncCompletion = {
            userDataSynced?.fulfill()
        }
        
        let installationServiceMock = InstallationDataServiceMock(mmContext: mm)
        installationServiceMock.syncCompletion = {
            installationDataSynced?.fulfill()
        }
        
        let notificationInteractionServiceMock = NotificationInteractionServiceMock(mmContext: mm, categories: nil)
        notificationInteractionServiceMock.syncCompletion = {
            notificationInteractionSynced?.fulfill()
        }
        
        let messageHandlerServiceMock = MessageHandlerMock(storage: storage, mmContext: mm)
        messageHandlerServiceMock.syncCompletion = {
            messagesSynced?.fulfill()
        }
        
        let chatServiceMock = ChatServiceMock(mmContext: mm)
        chatServiceMock.syncCompletion = {
            chatSynced?.fulfill()
        }
        mm.apnsRegistrationManager = ApnsRegistrationManagerDisabledStub(mmContext: mm)
        mm.userService = userServiceMock
        mm.installationService = installationServiceMock
        mm.notificationsInteractionService = notificationInteractionServiceMock
        MMInAppChatService.sharedInstance = chatServiceMock
        mm.messageHandler = messageHandlerServiceMock
        mm.doStart()
        
        self.waitForExpectations(timeout: 15, handler: nil)
    }
}
