//
//  RichNotificationsExtensions.swift
//
//  Created by Andrey Kadochnikov on 23/05/2017.
//
//

import Foundation
import UserNotifications

extension MobileMessaging {
	/// Fabric method for Mobile Messaging session.
	///
	/// App Groups used to share data among app Notification Extension and the main application itself. Provide the appropriate App Group ID for both application and application extension in order to keep them in sync.
	/// - remark: If you are facing with the following error in your console:
	/// `[User Defaults] Failed to read values in CFPrefsPlistSource<0xXXXXXXX> (Domain: ..., User: kCFPreferencesAnyUser, ByHost: Yes, Container: (null)): Using kCFPreferencesAnyUser with a container is only allowed for SystemContainers, detaching from cfprefsd`.
	/// Although this warning doesn't mean that our code doesn't work, you can shut it up by prefixing your App Group ID with a Team ID of a certificate that you are signing the build with. For example: `"9S95Y6XXXX.group.com.mobile-messaging.notification-service-extension"`. The App Group ID itself doesn't need to be changed though.
	/// - parameter appGroupId: An ID of an App Group
	@available(*, deprecated, message: "The function is deprecated. Please put your App Group Id as a String value for a key `com.mobilemessaging.app_group` in your main info dictionary (Info.plist by default).")
	public func withAppGroupId(_ appGroupId: String) -> MobileMessaging {
		self.appGroupId = appGroupId
		self.sharedNotificationExtensionStorage = DefaultSharedDataStorage(applicationCode: applicationCode, appGroupId: appGroupId)
		return self
	}
}

extension MM_MTMessage {
	
	@discardableResult func downloadImageAttachment(appGroupId: String? = nil, completion: @escaping (URL?, Error?) -> Void) -> RetryableDownloadTask? {
		guard let contentURL = contentUrl?.safeUrl else {
			logDebug("could not init content url to download")
			completion(nil, nil)
			return nil
		}

		let destinationResolver: (URL, URLResponse) -> URL = { _, _ -> URL in
			//NOTE: appGroupId may be passed here to save file in app group to be fetched by main app afterwards. currently not implemented completely because some questions need to be answered: 1. does OS cleans up AppGroup/Library/Caches directory? if not, implement own purhing mechanism; 2. is simple file manager write safe enough to be used in shared container, whe writer/reader problem may happen.
			let ret = URL.attachmentDownloadDestinatioUrl(sourceUrl: contentURL, appGroupId: nil)
			return ret
		}

		let task = RetryableDownloadTask(attemptsCount: 3, contentUrl: contentURL, destinationResolver: destinationResolver, completion: completion)
		logDebug("downloading rich content for message...")
		task.resume()
		
		return task
	}

}

@objcMembers
final public class MobileMessagingNotificationServiceExtension: NSObject, NamedLogger {
	
	/// Starts a new Mobile Messaging Notification Service Extension session.
	///
	/// This method should be called form `didReceive(_:, withContentHandler:)` of your subclass of UNNotificationServiceExtension.
	/// - parameter code: The application code of your Application from Push Portal website.
	/// - parameter appGroupId: An ID of an App Group. App Groups used to share data among app Notification Extension and the main application itself. Provide the appropriate App Group ID for both application and application extension in order to keep them in sync.
	/// - remark: If you are facing with the following error in your console:
	/// `[User Defaults] Failed to read values in CFPrefsPlistSource<0xXXXXXXX> (Domain: ..., User: kCFPreferencesAnyUser, ByHost: Yes, Container: (null)): Using kCFPreferencesAnyUser with a container is only allowed for SystemContainers, detaching from cfprefsd`.
	/// Although this warning doesn't mean that our code doesn't work, you can shut it up by prefixing your App Group ID with a Team ID of a certificate that you are signing the build with. For example: `"9S95Y6XXXX.group.com.mobile-messaging.notification-service-extension"`. The App Group ID itself doesn't need to be changed though.
	@available(*, deprecated, message: "The function is deprecated. Plese use `startWithApplicationCode(_ applicationCode: String)` instead and put your App Group Id as a String value for a key `com.mobilemessaging.app_group` respectively in your main info dictionary (info .plist file).")
	public class func startWithApplicationCode(_ code: String, appGroupId: String) {
		if sharedInstance == nil {
			sharedInstance = MobileMessagingNotificationServiceExtension(appCode: code, appGroupId: appGroupId)
		}
		sharedInstance?.sharedNotificationExtensionStorage = DefaultSharedDataStorage(applicationCode: code, appGroupId: appGroupId)
	}

	/// Starts a new Mobile Messaging Notification Service Extension session.
	///
	/// This method should be called form `didReceive(_:, withContentHandler:)` of your subclass of UNNotificationServiceExtension.
	/// - parameter applicationCode: The application code of your Application from Push Portal website.
	///
	/// **It is required for the session start to put your App Group Id as a String value for a key** `com.mobilemessaging.app_group` **in your main info dictionary (info .plist file)**
	/// - remark: If you are facing with the following error in your console:
	/// `[User Defaults] Failed to read values in CFPrefsPlistSource<0xXXXXXXX> (Domain: ..., User: kCFPreferencesAnyUser, ByHost: Yes, Container: (null)): Using kCFPreferencesAnyUser with a container is only allowed for SystemContainers, detaching from cfprefsd`.
	/// Although this warning doesn't mean that our code doesn't work, you can shut it up by prefixing your App Group ID with a Team ID of a certificate that you are signing the build with. For example: `"9S95Y6XXXX.group.com.mobile-messaging.notification-service-extension"`. The App Group ID itself doesn't need to be changed though.
	public class func startWithApplicationCode(_ applicationCode: String) {
		guard let appGroupId = Bundle.mainAppBundle.appGroupId else {
			logError("App Group Id is not provided in Notification Extension target info dictionary")
			return
		}
		if sharedInstance == nil {
			sharedInstance = MobileMessagingNotificationServiceExtension(appCode: applicationCode, appGroupId: appGroupId)
		}
		sharedInstance?.sharedNotificationExtensionStorage = DefaultSharedDataStorage(applicationCode: applicationCode, appGroupId: appGroupId)
	}

    /// This method handles an incoming notification on the Notification Service Extensions side. It performs message delivery reporting and downloads data from `contentUrl` if provided. This method must be called within `UNNotificationServiceExtension.didReceive(_: withContentHandler:)` callback.
    ///
    /// - parameter request: The original notification request. Use this object to get the original content of the notification.
    /// - parameter contentHandler: The block to execute with the modified content. The block will be called after the delivery reporting and contend downloading finished.
    public class func didReceive(_ request: UNNotificationRequest, 
                                 withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        logDebug("did receive request \(request)")
        didReceive(content: request.content, withContentHandler: contentHandler)
    }

    /// This method handles an incoming notification on the Notification Service Extensions side. It performs message delivery reporting and downloads data from `contentUrl` if provided. This method must be called within `UNNotificationServiceExtension.didReceive(_: withContentHandler:)` callback.
	///
    /// - parameter content: The notification request content.
    /// - parameter contentHandler: The block to execute with the modified content. The block will be called after the delivery reporting and contend downloading finished.
	public class func didReceive(content: UNNotificationContent,
                                 withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        var result = content
        
		guard let sharedInstance = sharedInstance,
			let mtMessage = MM_MTMessage(payload: result.userInfo,
									  deliveryMethod: .push,
									  seenDate: nil,
									  deliveryReportDate: nil,
									  seenStatus: .NotSeen,
									  isDeliveryReportSent: false) else
		{
			logDebug("could not recognize message")
			contentHandler(result)
			return
		}
		
		let handlingGroup = DispatchGroup()
		
		handlingGroup.enter()
		sharedInstance.reportDelivery(mtMessage) { error in
			mtMessage.isDeliveryReportSent = error == nil
			mtMessage.deliveryReportedDate = mtMessage.isDeliveryReportSent ? MobileMessaging.date.now : nil
			logDebug("saving message to shared storage \(sharedInstance.sharedNotificationExtensionStorage.orNil)")
			sharedInstance.sharedNotificationExtensionStorage?.save(message: mtMessage)
			handlingGroup.leave()
		}
		
		handlingGroup.enter()
		sharedInstance.retrieveNotificationContent(for: mtMessage, originalContent: result) { updatedContent in
			result = updatedContent
			handlingGroup.leave()
		}
		
		handlingGroup.notify(queue: DispatchQueue.main) {
			logDebug("message handling finished")
			contentHandler(result)
		}
	}

	// This method finishes the MobileMessaging SDK internal procedures in order to prepare for termination. This method must be called within your `UNNotificationServiceExtension.serviceExtensionTimeWillExpire()` callback.
	public class func serviceExtensionTimeWillExpire() {
		sharedInstance?.currentTask?.cancel()
	}
	
	//MARK: Internal
	let sessionManager: DynamicBaseUrlHTTPSessionManager
	static var sharedInstance: MobileMessagingNotificationServiceExtension?
	private init(appCode: String, appGroupId: String) {
		self.applicationCode = appCode
		self.appGroupId = appGroupId
		self.sessionManager = DynamicBaseUrlHTTPSessionManager(baseURL: URL(string: Consts.APIValues.prodDynamicBaseURLString)!, sessionConfiguration: MobileMessaging.urlSessionConfiguration, appGroupId: appGroupId)
	}
	
	private func retrieveNotificationContent(for message: MM_MTMessage, originalContent: UNNotificationContent, completion: @escaping (UNNotificationContent) -> Void) {
		
		currentTask = message.downloadImageAttachment(appGroupId: appGroupId) { (downloadedFileUrl, error) in
			guard let downloadedFileUrl = downloadedFileUrl,
				let mContent = (originalContent.mutableCopy() as? UNMutableNotificationContent),
				let attachment = try? UNNotificationAttachment(identifier: downloadedFileUrl.absoluteString.sha256(), url: downloadedFileUrl, options: nil)
				else
			{
				self.logDebug("rich content downloading completed, could not init content attachment")
				completion(originalContent)
				return
			}

//			message.downloadedPictureUrl = downloadedFileUrl
			mContent.attachments = [attachment]
			self.logDebug("rich content downloading completed succesfully")
			completion((mContent.copy() as? UNNotificationContent) ?? originalContent)
		}
	}
	
	private func reportDelivery(_ message: MM_MTMessage, completion: @escaping (NSError?) -> Void) {
		deliveryReporter.report(applicationCode: applicationCode, messageIds: [message.messageId], completion: completion)
	}
	
	let appGroupId: String
	let applicationCode: String
	let remoteAPIBaseURL = Consts.APIValues.prodDynamicBaseURLString
	var currentTask: RetryableDownloadTask?
	var sharedNotificationExtensionStorage: AppGroupMessageStorage?
	lazy var deliveryReporter: DeliveryReporting! = DeliveryReporter()
}

protocol DeliveryReporting {
	func report(applicationCode: String, messageIds: [String], completion: @escaping (NSError?) -> Void)
}

class DeliveryReporter: DeliveryReporting, NamedLogger {
	func report(applicationCode: String, messageIds: [String], completion: @escaping (NSError?) -> Void) {
		logDebug("reporting delivery for message ids \(messageIds)")
		guard let extensionInstance = MobileMessagingNotificationServiceExtension.sharedInstance, !messageIds.isEmpty else
		{
			logDebug("[Notification Extension] could not report delivery")
			completion(nil)
			return
		}
		let request = DeliveryReportRequest(applicationCode: applicationCode, body: [Consts.DeliveryReport.dlrMessageIds: messageIds])
        extensionInstance.sessionManager.getDataResponse(request, queue: DispatchQueue.global(), completion: { completion($1) })
	}
}

protocol AppGroupMessageStorage {
	init?(applicationCode: String, appGroupId: String)
	func save(message: MM_MTMessage)
	func retrieveMessages() -> [MM_MTMessage]
	func cleanupMessages()
}

class DefaultSharedDataStorage: AppGroupMessageStorage {
	let applicationCode: String
	let appGroupId: String
	let storage: UserDefaults
	required init?(applicationCode: String, appGroupId: String) {
		guard let ud = UserDefaults.init(suiteName: appGroupId) else {
			return nil
		}
		self.appGroupId = appGroupId
		self.applicationCode = applicationCode
		self.storage = ud
	}
	
	func save(message: MM_MTMessage) {
		var savedMessageDicts = retrieveSavedPayloadDictionaries()
		var msgDict: MMStringKeyPayload = ["p": message.originalPayload, "dlr": message.isDeliveryReportSent]
//		msgDict["downloadedPicUrl"] = message.downloadedPictureUrl?.absoluteString
		msgDict["dlrd"] = message.deliveryReportedDate
		savedMessageDicts.append(msgDict)
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: savedMessageDicts, requiringSecureCoding: true) {
            storage.set(data, forKey: applicationCode)
            storage.synchronize()
        }
	}
	
	func retrieveMessages() -> [MM_MTMessage] {
        let messageDataDicts = retrieveSavedPayloadDictionaries()
		let messages = messageDataDicts.compactMap({ messageDataTuple -> MM_MTMessage? in
			guard let payload = messageDataTuple["p"] as? MMStringKeyPayload, let dlrSent =  messageDataTuple["dlr"] as? Bool else
			{
				return nil
			}
			let newMessage = MM_MTMessage(payload: payload,
									   deliveryMethod: .local,
									   seenDate: nil,
									   deliveryReportDate: messageDataTuple["dlrd"] as? Date,
									   seenStatus: .NotSeen,
									   isDeliveryReportSent: dlrSent)

//			if let urlStr = messageDataTuple["downloadedPicUrl"] as? String, let url = URL(string: urlStr) {
//				newMessage?.downloadedPictureUrl = url
//			}
			return newMessage
		})
		return messages
	}
	
	func cleanupMessages() {
		storage.removeObject(forKey: applicationCode)
	}
    
    private func retrieveSavedPayloadDictionaries() -> [MMStringKeyPayload] {
        var payloadDictionaries = [MMStringKeyPayload]();
        if let data = storage.object(forKey: applicationCode) as? Data,
           let dictionaries = unarchiveMessageDictionaries(fromeData: data) {
            payloadDictionaries = dictionaries
        } else if let dictionaries = storage.object(forKey: applicationCode) as? [MMStringKeyPayload] { //migration from saving as Dictionaries
            payloadDictionaries = dictionaries
        }
        return payloadDictionaries
    }
    
    private func unarchiveMessageDictionaries(fromeData data: Data) -> [MMStringKeyPayload]? {
        do {
            return try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSDictionary.self, NSNull.self, NSString.self, NSNumber.self], from: data) as? [MMStringKeyPayload] //saved as Data for supporting NSNull in payload
        } catch {
            MMLogError("[AppGroupMessageStorage] couldn't unarchive message objects with error: \(error)")
        }
        return nil
    }
}
