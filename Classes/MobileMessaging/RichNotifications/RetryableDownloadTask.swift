//
//  RetryableDownloadTask.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2026 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

class RetryableDownloadTask: NamedLogger {
	let contentUrl: URL
	let destinationResolver: (URL, URLResponse) -> URL
	let completion: (URL?, Error?) -> Void
	var currentTask: URLSessionDownloadTask?
	let maxAttempts: UInt
	private var attemptsMade: UInt = 0

	private lazy var urlSession: URLSession = {
		let config = MobileMessaging.urlSessionConfiguration
		config.timeoutIntervalForResource = 20
		config.timeoutIntervalForRequest = 20
		return URLSession(configuration: config)
	}()

	init(attemptsCount: UInt, contentUrl: URL, destinationResolver: @escaping (URL, URLResponse) -> URL, completion: @escaping (URL?, Error?) -> Void) {
		self.maxAttempts = attemptsCount
		self.contentUrl = contentUrl
		self.completion = completion
		self.destinationResolver = destinationResolver
	}

	func resume() {
		attemptsMade += 1
		let request = URLRequest(url: contentUrl)
		logDebug("starting download attempt \(attemptsMade)/\(maxAttempts) with request \(request)...")

		let task = urlSession.downloadTask(with: request) { [weak self] tempURL, response, error in
			guard let self = self else { return }

			if let error = error {
				if self.attemptsMade < self.maxAttempts {
					self.logDebug("download attempt \(self.attemptsMade) failed: \(error), retrying...")
					self.resume()
					return
				}
				self.logDebug("finishing with error \(error)")
				self.completion(nil, error)
				return
			}

			guard let tempURL = tempURL, let response = response else {
				self.logDebug("finishing with no data and no error")
				self.completion(nil, nil)
				return
			}

			let destinationURL = self.destinationResolver(tempURL, response)
			do {
				let fm = FileManager.default
				if fm.fileExists(atPath: destinationURL.path) {
					try fm.removeItem(at: destinationURL)
				}
				try fm.moveItem(at: tempURL, to: destinationURL)
				self.logDebug("download completed to \(destinationURL)")
				self.completion(destinationURL, nil)
			} catch {
				self.logDebug("finishing with file error \(error)")
				self.completion(nil, error)
			}
		}
		currentTask = task
		task.resume()
	}

	func cancel() {
		currentTask?.cancel()
	}
}
