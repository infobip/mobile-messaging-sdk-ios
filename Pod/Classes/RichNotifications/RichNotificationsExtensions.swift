//
//  RichNotificationsExtensions.swift
//
//  Created by Andrey Kadochnikov on 23/05/2017.
//
//

import Foundation
import UserNotifications

extension MTMessage {
	
	static let attachmentsUrlSessionManager = MM_AFHTTPSessionManager(sessionConfiguration: MobileMessaging.urlSessionConfiguration)
	
	@discardableResult func downloadImageAttachment(completion: @escaping (URL?, Error?) -> Void) -> URLSessionDownloadTask? {
		guard let contentUrlString = contentUrl, let contentURL = URL.init(string: contentUrlString) else {
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
		MTMessage.attachmentsUrlSessionManager.session.configuration.timeoutIntervalForResource = 20 //this will help to avoid too long downloading task (in case of big pictures)
		MTMessage.attachmentsUrlSessionManager.session.configuration.timeoutIntervalForRequest = 20
		let task = MTMessage.attachmentsUrlSessionManager.downloadTask(with: URLRequest(url: contentURL), progress: nil, destination: destination) { (urlResponse, url, error) in
			completion(url, error)
		}
		task.resume()
		return task
	}
}

@available(iOS 10.0, *)
final public class MobileMessagingNotificationServiceExtension: NSObject {
	
	public class func startWithApplicationCode(_ code: String, appGroupId: String) {
		if sharedInstance == nil {
			sharedInstance = MobileMessagingNotificationServiceExtension(appCode: code, appGroupId: appGroupId)
		}
	}
	
	public class func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
		guard let sharedInstance = sharedInstance, let mtMessage = MTMessage(payload: request.content.userInfo, createdDate: Date()) else
		{
			contentHandler(request.content)
			return
		}
		sharedInstance.reportDelivery(mtMessage)
		sharedInstance.currentTask = mtMessage.downloadImageAttachment { (url, error) in
			guard let url = url,
				let mContent = (request.content.mutableCopy() as? UNMutableNotificationContent),
				let attachment = try? UNNotificationAttachment(identifier: String(url.absoluteString.hash), url: url, options: nil) else
			{
				contentHandler(request.content)
				return
			}
			
			mContent.attachments = [attachment]
			
			let result: UNNotificationContent
			if let contentWithAttach = mContent.copy() as? UNNotificationContent {
				result = contentWithAttach
			} else {
				result = request.content
			}
			contentHandler(result)
		}
	}
	
	public class func serviceExtensionTimeWillExpire() {
		sharedInstance?.currentTask?.cancel()
	}
	
	//MARK: Internal
	static var sharedInstance: MobileMessagingNotificationServiceExtension?
	private init(appCode: String, appGroupId: String) {
		self.applicationCode = appCode
		self.appGroupId = appGroupId
	}
	
	private func reportDelivery(_ message: MTMessage) {
		DeliveryReportRequest(dlrIds: [message.messageId])?.responseObject(applicationCode: applicationCode, baseURL: remoteAPIBaseURL) { response in
			self.persistMessage(message, isDelivered: response.error == nil)
		}
	}
	
	private func persistMessage(_ message: MTMessage, isDelivered: Bool) {
		guard let ud = UserDefaults.notificationServiceExtensionContainer else {
			return
		}
		var savedMessageDicts = ud.object(forKey: applicationCode) as? [StringKeyPayload] ?? []
		savedMessageDicts.append(["p": message.originalPayload, "d": message.createdDate, "dlr": isDelivered])
		ud.set(savedMessageDicts, forKey: applicationCode)
		ud.synchronize()
	}
	
	let appGroupId: String
	let applicationCode: String
	let remoteAPIBaseURL = APIValues.prodBaseURLString
	var currentTask: URLSessionDownloadTask?
}
