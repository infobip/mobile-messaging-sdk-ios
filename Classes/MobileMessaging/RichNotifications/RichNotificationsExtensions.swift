// 
//  RichNotificationsExtensions.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import UserNotifications

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

protocol AppGroupMessageStorage {
	init?(applicationCode: String, appGroupId: String)
	func save(message: MM_MTMessage)
	func retrieveMessages() -> [MM_MTMessage]
	func cleanupMessages()
}

// NOTE: Storage format (keys "p", "dlr", "dlrd" and NSKeyedArchiver serialization) is shared with MMNSESharedStorage in MobileMessagingNotificationExtension module. Any changes here must be mirrored there.
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
            return try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSDictionary.self, NSNull.self, NSString.self, NSNumber.self, NSDate.self], from: data) as? [MMStringKeyPayload] //saved as Data for supporting NSNull in payload
        } catch {
            MMLogError("[AppGroupMessageStorage] couldn't unarchive message objects with error: \(error)")
        }
        return nil
    }
}
