//
//  MobileMessagingNotificationServiceExtension.swift
//  MobileMessagingNotificationExtension
//
//  Copyright (c) 2016-2026 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import UserNotifications

public class MobileMessagingNotificationServiceExtension {

    /// This method handles an incoming notification on the Notification Service Extension side. It performs message delivery reporting and downloads data from `contentUrl` if provided. This method must be called within `UNNotificationServiceExtension.didReceive(_: withContentHandler:)` callback.
    ///
    /// - parameter request: The original notification request. Use this object to get the original content of the notification.
    /// - parameter contentHandler: The block to execute with the modified content.
    public class func didReceive(_ request: UNNotificationRequest,
                                 withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        MMNSELogger.logDebug("did receive request \(request)")
        didReceive(content: request.content, withContentHandler: contentHandler)
    }

    /// This method handles an incoming notification on the Notification Service Extension side. It performs message delivery reporting and downloads data from `contentUrl` if provided. This method must be called within `UNNotificationServiceExtension.didReceive(_: withContentHandler:)` callback.
    ///
    /// - parameter content: The notification request content.
    /// - parameter contentHandler: The block to execute with the modified content.
    public class func didReceive(content: UNNotificationContent,
                                 withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        if sharedInstance == nil {
            let appGroupId = Bundle.mainAppBundle.appGroupId
            let keychain = MMNSEKeychain(accessGroup: appGroupId)

            guard let applicationCode = keychain.applicationCode else {
                MMNSELogger.logError("Could not start notification extension. ApplicationCode not found in keychain.")
                contentHandler(content)
                return
            }
            guard let appGroupId = appGroupId else {
                MMNSELogger.logError("Could not start notification extension. AppGroupId not defined in info.plist.")
                contentHandler(content)
                return
            }

            sharedInstance = MobileMessagingNotificationServiceExtension(appCode: applicationCode, appGroupId: appGroupId)
        }

        guard let sharedInstance = sharedInstance,
              let userInfo = content.userInfo as? [String: Any],
              let message = MMNSEMessage(payload: userInfo) else {
            MMNSELogger.logDebug("could not recognize message")
            contentHandler(content)
            return
        }

        contentHandlerDone = false
        storedContentHandler = contentHandler
        storedOriginalContent = content

        handlingTask = Task {
            let result = await sharedInstance.handleNotification(message: message, content: content)
            finish(with: result)
        }
    }

    /// This method finishes the MobileMessaging SDK internal procedures in order to prepare for termination. This method must be called within your `UNNotificationServiceExtension.serviceExtensionTimeWillExpire()` callback.
    ///
    /// This method cancels any in-progress work. Callers should call the content handler
    /// themselves after calling this method, following the standard Apple extension pattern.
    public class func serviceExtensionTimeWillExpire() {
        handlingTask?.cancel()
        contentHandlerDone = true
        storedContentHandler = nil
        storedOriginalContent = nil
    }

    /// Validates whether the payload is a correct Infobip message payload.
    public class func isCorrectPayload(_ payload: [String: Any]) -> Bool {
        return MMNSEMessage.isCorrectPayload(payload)
    }

    // MARK: - Internal

    private static var sharedInstance: MobileMessagingNotificationServiceExtension?
    private static var handlingTask: Task<Void, Never>?
    private static var storedContentHandler: ((UNNotificationContent) -> Void)?
    private static var storedOriginalContent: UNNotificationContent?
    private static var contentHandlerDone = false

    private let applicationCode: String
    private let appGroupId: String
    private let pushRegId: String?
    private let deliveryReporter: MMNSEDeliveryReporter
    private let downloader = MMNSEAttachmentDownloader()
    private var sharedStorage: MMNSESharedStorage?

    private init(appCode: String, appGroupId: String) {
        self.applicationCode = appCode
        self.appGroupId = appGroupId

        let keychain = MMNSEKeychain(accessGroup: appGroupId)
        self.pushRegId = keychain.pushRegId

        let storage = UserDefaults(suiteName: appGroupId) ?? UserDefaults.standard
        self.deliveryReporter = MMNSEDeliveryReporter(applicationCode: appCode, appGroupId: appGroupId, storage: storage)
        self.sharedStorage = MMNSESharedStorage(applicationCode: appCode, appGroupId: appGroupId)
    }

    private class func finish(with content: UNNotificationContent) {
        guard !contentHandlerDone else {
            MMNSELogger.logDebug("contentHandler already called, skipping")
            return
        }
        contentHandlerDone = true
        MMNSELogger.logDebug("message handling finished")
        storedContentHandler?(content)
        storedContentHandler = nil
        storedOriginalContent = nil
    }

    private func handleNotification(message: MMNSEMessage, content: UNNotificationContent) async -> UNNotificationContent {
        // Run delivery report and attachment download in parallel
        async let deliveryResult: () = reportDelivery(for: message)
        async let attachmentResult: UNNotificationContent = retrieveNotificationContent(for: message, originalContent: content)

        // Await both
        _ = await deliveryResult
        let result = await attachmentResult

        return result
    }

    private func reportDelivery(for message: MMNSEMessage) async {
        var message = message
        do {
            try await deliveryReporter.report(messageIds: [message.messageId], pushRegId: pushRegId)
            message.isDeliveryReportSent = true
            message.deliveryReportedDate = Date()
        } catch {
            MMNSELogger.logError("delivery reporting failed: \(error)")
            message.isDeliveryReportSent = false
            message.deliveryReportedDate = nil
        }
        MMNSELogger.logDebug("saving message to shared storage")
        sharedStorage?.save(message: message)
    }

    private func retrieveNotificationContent(for message: MMNSEMessage, originalContent: UNNotificationContent) async -> UNNotificationContent {
        guard let contentUrlString = message.contentUrl, let contentUrl = contentUrlString.safeUrl else {
            MMNSELogger.logDebug("could not init content url to download")
            return originalContent
        }

        MMNSELogger.logDebug("downloading rich content for message...")
        do {
            let downloadedFileUrl = try await downloader.download(contentUrl: contentUrl)
            guard let mContent = originalContent.mutableCopy() as? UNMutableNotificationContent,
                  let attachment = try? UNNotificationAttachment(
                    identifier: downloadedFileUrl.absoluteString.sha256(),
                    url: downloadedFileUrl,
                    options: nil
                  )
            else {
                MMNSELogger.logDebug("rich content downloading completed, could not init content attachment")
                return originalContent
            }
            mContent.attachments = [attachment]
            MMNSELogger.logDebug("rich content downloading completed successfully")
            return (mContent.copy() as? UNNotificationContent) ?? originalContent
        } catch {
            MMNSELogger.logDebug("rich content downloading failed: \(error)")
            return originalContent
        }
    }
}
