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
	public func withAppGroupId(_ appGroupId: String) -> MobileMessaging {
		if #available(iOS 10.0, *) {
			self.appGroupId = appGroupId
			self.sharedNotificationExtensionStorage = DefaultSharedDataStorage(applicationCode: applicationCode, appGroupId: appGroupId)
		}
		return self
	}
}

extension MTMessage {
	
	@discardableResult func downloadImageAttachment(completion: @escaping (URL?, Error?) -> Void) -> RetryableDownloadTask? {
		guard let contentUrlString = contentUrl, let contentURL = URL.init(string: contentUrlString) else {
			MMLogDebug("[Notification Extension] could not init content url to download")
			completion(nil, nil)
			return nil
		}

		let destination: ((URL, URLResponse) -> URL) = { url, _ -> URL in
			let tempFolderUrl = URL.init(fileURLWithPath: NSTemporaryDirectory())
			var destinationFolderURL = tempFolderUrl.appendingPathComponent("com.mobile-messaging.rich-notifications-attachments", isDirectory: true)
			
			var isDir: ObjCBool = true
			if !FileManager.default.fileExists(atPath: destinationFolderURL.path, isDirectory: &isDir) {
				do {
					try FileManager.default.createDirectory(at: destinationFolderURL, withIntermediateDirectories: true, attributes: nil)
				} catch _ {
					destinationFolderURL = tempFolderUrl
				}
			}
			return destinationFolderURL.appendingPathComponent(String(url.absoluteString.hashValue) + "." + contentURL.pathExtension)
		}
	
		let task = RetryableDownloadTask(attemptsCount: 3, request: URLRequest(url: contentURL), destination: destination, completion: completion)
		MMLogDebug("[Notification Extension] downloading rich content for message...")
		task.resume()
		
		return task
	}

}

@available(iOS 10.0, *)
@objcMembers
final public class MobileMessagingNotificationServiceExtension: NSObject {
	
	/// Starts a new Mobile Messaging Notification Service Extension session.
	///
	/// This method should be called form `didReceive(_:, withContentHandler:)` of your subclass of UNNotificationServiceExtension.
	/// - parameter code: The application code of your Application from Push Portal website.
	/// - parameter appGroupId: An ID of an App Group. App Groups used to share data among app Notification Extension and the main application itself. Provide the appropriate App Group ID for both application and application extension in order to keep them in sync.
	/// - remark: If you are facing with the following error in your console:
	/// `[User Defaults] Failed to read values in CFPrefsPlistSource<0xXXXXXXX> (Domain: ..., User: kCFPreferencesAnyUser, ByHost: Yes, Container: (null)): Using kCFPreferencesAnyUser with a container is only allowed for SystemContainers, detaching from cfprefsd`.
	/// Although this warning doesn't mean that our code doesn't work, you can shut it up by prefixing your App Group ID with a Team ID of a certificate that you are signing the build with. For example: `"9S95Y6XXXX.group.com.mobile-messaging.notification-service-extension"`. The App Group ID itself doesn't need to be changed though.
	public class func startWithApplicationCode(_ code: String, appGroupId: String) {
		if sharedInstance == nil {
			sharedInstance = MobileMessagingNotificationServiceExtension(appCode: code, appGroupId: appGroupId)
		}
		sharedInstance?.sharedNotificationExtensionStorage = DefaultSharedDataStorage(applicationCode: code, appGroupId: appGroupId)
	}
	
	/// This method handles an incoming notification on the Notification Service Extensions side. It performs message delivery reporting and downloads data from `contentUrl` if provided. This method must be called within `UNNotificationServiceExtension.didReceive(_: withContentHandler:)` callback.
	///
	/// - parameter request: The original notification request. Use this object to get the original content of the notification.
	/// - parameter contentHandler: The block to execute with the modified content. The block will be called after the delivery reporting and contend downloading finished.
	public class func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
		MMLogDebug("[Notification Extension] did receive request \(request)")
		var result: UNNotificationContent = request.content
		
		guard let sharedInstance = sharedInstance,
			let mtMessage = MTMessage(payload: request.content.userInfo,
									  deliveryMethod: .push,
									  seenDate: nil,
									  deliveryReportDate: nil,
									  seenStatus: .NotSeen,
									  isDeliveryReportSent: false) else
		{
			MMLogDebug("[Notification Extension] could not recognize message")
			contentHandler(result)
			return
		}
		
		let handlingGroup = DispatchGroup()
		
		handlingGroup.enter()
		sharedInstance.reportDelivery(mtMessage) { result in
			mtMessage.isDeliveryReportSent = result.error == nil
			mtMessage.deliveryReportedDate = mtMessage.isDeliveryReportSent ? MobileMessaging.date.now : nil
			MMLogDebug("[Notification Extension] saving message to shared storage \(String(describing: sharedInstance.sharedNotificationExtensionStorage))")
			sharedInstance.sharedNotificationExtensionStorage?.save(message: mtMessage)
			handlingGroup.leave()
		}
		
		handlingGroup.enter()
		sharedInstance.retrieveNotificationContent(for: mtMessage, originalContent: result) { updatedContent in
			result = updatedContent
			handlingGroup.leave()
		}
		
		handlingGroup.notify(queue: DispatchQueue.main) {
			MMLogDebug("[Notification Extension] message handling finished")
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
		self.sessionManager = DynamicBaseUrlHTTPSessionManager(applicationCode: appCode, baseURL: URL(string: APIValues.prodDynamicBaseURLString), sessionConfiguration: MobileMessaging.urlSessionConfiguration, appGroupId: appGroupId)
	}
	
	private func retrieveNotificationContent(for message: MTMessage, originalContent: UNNotificationContent, completion: @escaping (UNNotificationContent) -> Void) {
		
		currentTask = message.downloadImageAttachment { (url, error) in
			guard let url = url,
				let mContent = (originalContent.mutableCopy() as? UNMutableNotificationContent),
				let attachment = try? UNNotificationAttachment(identifier: String(url.absoluteString.hash), url: url, options: nil) else
			{
				MMLogDebug("[Notification Extension] rich content downloading completed, could not init content attachment")
				completion(originalContent)
				return
			}
			
			mContent.attachments = [attachment]
			
			MMLogDebug("[Notification Extension] rich content downloading completed succesfully")
			completion((mContent.copy() as? UNNotificationContent) ?? originalContent)
		}
	}
	
	private func reportDelivery(_ message: MTMessage, completion: @escaping (Result<DeliveryReportResponse>) -> Void) {
		deliveryReporter.report(messageIds: [message.messageId], completion: completion)
	}
	
	let appGroupId: String
	let applicationCode: String
	let remoteAPIBaseURL = APIValues.prodDynamicBaseURLString
	var currentTask: RetryableDownloadTask?
	var sharedNotificationExtensionStorage: AppGroupMessageStorage?
	lazy var deliveryReporter: DeliveryReporting! = DeliveryReporter()
}

protocol DeliveryReporting {
	func report(messageIds: [String], completion: @escaping (Result<DeliveryReportResponse>) -> Void)
}

@available(iOS 10.0, *)
class DeliveryReporter: DeliveryReporting {
	func report(messageIds: [String], completion: @escaping (Result<DeliveryReportResponse>) -> Void) {
		MMLogDebug("[Notification Extension] reporting delivery for message ids \(messageIds)")
		guard let dlr = DeliveryReportRequest(dlrIds: messageIds), let extensionInstance = MobileMessagingNotificationServiceExtension.sharedInstance else
		{
			MMLogDebug("[Notification Extension] could not report delivery")
			completion(Result.Cancel)
			return
		}
		extensionInstance.sessionManager.sendRequest(dlr, completion: completion)
	}
}

protocol AppGroupMessageStorage {
	init?(applicationCode: String, appGroupId: String)
	func save(message: MTMessage)
	func retrieveMessages() -> [MTMessage]
	func cleanupMessages()
}

@available(iOS 10.0, *)
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
	
	func save(message: MTMessage) {
		var savedMessageDicts = storage.object(forKey: applicationCode) as? [StringKeyPayload] ?? [StringKeyPayload]()
		var msgDict: StringKeyPayload = ["p": message.originalPayload, "dlr": message.isDeliveryReportSent]
		msgDict["dlrd"] = message.deliveryReportedDate
		savedMessageDicts.append(msgDict)
		storage.set(savedMessageDicts, forKey: applicationCode)
		storage.synchronize()
	}
	
	func retrieveMessages() -> [MTMessage] {
		guard let messageDataDicts = storage.array(forKey: applicationCode) as? [StringKeyPayload] else
		{
			return []
		}
		let messages = messageDataDicts.compactMap({ messageDataTuple -> MTMessage? in
			guard let payload = messageDataTuple["p"] as? StringKeyPayload, let dlrSent =  messageDataTuple["dlr"] as? Bool else
			{
				return nil
			}
			let newMessage = MTMessage(payload: payload,
									   deliveryMethod: .local,
									   seenDate: nil,
									   deliveryReportDate: messageDataTuple["dlrd"] as? Date,
									   seenStatus: .NotSeen,
									   isDeliveryReportSent: dlrSent)
			return newMessage
		})
		return messages
	}
	
	func cleanupMessages() {
		storage.removeObject(forKey: applicationCode)
	}
}
