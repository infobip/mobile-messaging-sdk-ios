//
//  RetryableDownloadTask.swift
//
//  Created by okoroleva on 14.06.17.
//
//

class RetryableDownloadTask: NamedLogger {
	let contentUrl: URL
	let destinationResolver: (URL, URLResponse) -> URL
	let completion: (URL?, Error?) -> Void
	var currentTask: URLSessionDownloadTask?
	lazy var sessionManager: SessionManager  = {
		let manager = SessionManager(configuration: MobileMessaging.urlSessionConfiguration)
		manager.session.configuration.timeoutIntervalForResource = 20 //this will help to avoid too long downloading task (in case of big pictures)
		manager.session.configuration.timeoutIntervalForRequest = 20
		return manager
	}()
	
	init(attemptsCount: UInt, contentUrl: URL, destinationResolver: @escaping (URL, URLResponse) -> URL, completion: @escaping (URL?, Error?) -> Void) {
		self.contentUrl = contentUrl
		self.completion = completion
		self.destinationResolver = destinationResolver
	}
	
	func resume() {
		let request = URLRequest(url: contentUrl)
		logDebug("starting downloading with request \(request)...")
		
		let destination: DownloadRequest.DownloadFileDestination = { url, urlResponse in
			return (self.destinationResolver(url, urlResponse), DownloadRequest.DownloadOptions.removePreviousFile)
		}
		sessionManager.download(request, to: destination).responseData { (downloadResult) in
			
			self.logDebug("finishing with error \(downloadResult.error.orNil)")
			self.completion(downloadResult.destinationURL, downloadResult.error as NSError?)
		}
	}
	
	func cancel() {
		currentTask?.cancel()
	}
}
