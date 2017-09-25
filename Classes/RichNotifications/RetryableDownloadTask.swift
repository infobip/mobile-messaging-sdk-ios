//
//  RetryableDownloadTask.swift
//
//  Created by okoroleva on 14.06.17.
//
//

class RetryableDownloadTask {
	var attemptsRemaining: UInt
	let request: URLRequest
	let destination: ((URL, URLResponse) -> URL)
	let completion: (URL?, Error?) -> Void
	var currentTask: URLSessionDownloadTask?
	lazy var sessionManager: MM_AFHTTPSessionManager  = {
		let manager = MM_AFHTTPSessionManager(sessionConfiguration: MobileMessaging.urlSessionConfiguration)
		manager.session.configuration.timeoutIntervalForResource = 20 //this will help to avoid too long downloading task (in case of big pictures)
		manager.session.configuration.timeoutIntervalForRequest = 20
		return manager
	}()
	
	init(attemptsCount: UInt, request: URLRequest, destination: @escaping ((URL, URLResponse) -> URL), completion: @escaping (URL?, Error?) -> Void) {
		self.attemptsRemaining = attemptsCount
		self.request = request
		self.destination = destination
		self.completion = completion
	}
	
	func resume() {
		currentTask = sessionManager.downloadTask(with: request, progress: nil, destination: destination)
		{ (urlResponse, url, error) in
			if let error = error, (error as NSError).mm_isRetryable, self.attemptsRemaining > 0 {
				self.attemptsRemaining -= 1
				self.resume()
			} else {
				self.completion(url, error)
			}
		}
		currentTask?.resume()
	}
	
	func cancel() {
		currentTask?.cancel()
	}
}
