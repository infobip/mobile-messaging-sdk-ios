//
//  RetryableDownloadTask.swift
//
//  Created by okoroleva on 14.06.17.
//
//

class RetryableDownloadTask {
	var attemptsRemaining: UInt
	let contentUrl: URL
	let destinationResolver: (URL, URLResponse) -> URL
	let completion: (URL?, Error?) -> Void
	var currentTask: URLSessionDownloadTask?
	lazy var sessionManager: MM_AFHTTPSessionManager  = {
		let manager = MM_AFHTTPSessionManager(sessionConfiguration: MobileMessaging.urlSessionConfiguration)
		manager.session.configuration.timeoutIntervalForResource = 20 //this will help to avoid too long downloading task (in case of big pictures)
		manager.session.configuration.timeoutIntervalForRequest = 20
		return manager
	}()
	
	init(attemptsCount: UInt, contentUrl: URL, destinationResolver: @escaping (URL, URLResponse) -> URL, completion: @escaping (URL?, Error?) -> Void) {
		self.attemptsRemaining = attemptsCount
		self.contentUrl = contentUrl
		self.completion = completion
		self.destinationResolver = destinationResolver
	}
	
	func resume() {
		let request = URLRequest(url: contentUrl)
		MMLogDebug("[Notification Extension] starting downloading with request \(request)...")
		currentTask = sessionManager.downloadTask(
			with: request,
			progress: nil,
			destination: destinationResolver,
			completionHandler: { (urlResponse, whereSavedUrl, error) in
				if let error = error, (error as NSError).mm_isRetryable, self.attemptsRemaining > 0 {
					MMLogDebug("[Notification Extension] received error \(error), retrying...")
					self.attemptsRemaining -= 1
					self.resume()
				} else {
					MMLogDebug("[Notification Extension] finishing with error \(error.orNil)")
					self.completion(whereSavedUrl, error)
				}
		})
		currentTask?.resume()
	}
	
	func cancel() {
		currentTask?.cancel()
	}
}
