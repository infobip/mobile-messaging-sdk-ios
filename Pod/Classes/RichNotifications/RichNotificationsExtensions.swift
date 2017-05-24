//
//  RichNotificationsExtensions.swift
//
//  Created by Andrey Kadochnikov on 23/05/2017.
//
//

import Foundation

extension MTMessage {
	
	static let attachmentsUrlSessionManager = MM_AFHTTPSessionManager(sessionConfiguration: MobileMessaging.urlSessionConfiguration)
	
	@discardableResult public func downloadImageAttachment(completion: @escaping (URL?, Error?) -> Void) -> URLSessionDownloadTask? {
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
