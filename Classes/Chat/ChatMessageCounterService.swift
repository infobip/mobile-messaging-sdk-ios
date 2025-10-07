// 
//  ChatMessageCounterService.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

class ChatMessageCounterService: MobileMessagingService {
    weak var chatService: MMInAppChatService?
    
    init(mmContext: MobileMessaging) {
        super.init(mmContext: mmContext, uniqueIdentifier: "ChatMessageCounterService")
    }
    
    override func handleNewMessage(_ message: MM_MTMessage, completion: @escaping (MessageHandlingResult) -> Void) {
        guard message.isChatMessage else {
            completion(MessageHandlingResult.noData)
            return
        }
        let internalData = mmContext.internalData()
        let newValue = internalData.chatMessageCounter + 1
        internalData.chatMessageCounter = newValue
        internalData.archiveCurrent()
        logDebug("counter set \(newValue)")
        completion(MessageHandlingResult.noData)
        callCounterHandler(newValue: newValue)
    }
    
    private func callCounterHandler(newValue: Int) {
        DispatchQueue.main.async {
            UserEventsManager.postInAppChatUnreadMessagesCounterUpdatedEvent(newValue)
            self.chatService?.delegate?.didUpdateUnreadMessagesCounter?(newValue)
        }
    }
    
    override func depersonalizeService(_ mmContext: MobileMessaging, userInitiated: Bool, completion: @escaping () -> Void) {
        resetCounter()
        completion()
    }
    
    func resetCounter() {
        let newValue = 0
        let internalData = mmContext.internalData()
        internalData.chatMessageCounter = newValue
        internalData.archiveCurrent()
        logDebug("counter reset")
        callCounterHandler(newValue: newValue)
    }
    
    func getCounter() -> Int {
        return mmContext.internalData().chatMessageCounter
    }
}
