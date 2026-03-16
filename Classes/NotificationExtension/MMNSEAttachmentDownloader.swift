//
//  MMNSEAttachmentDownloader.swift
//  MobileMessagingNotificationExtension
//
//  Copyright (c) 2016-2026 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

class MMNSEAttachmentDownloader {
    let maxRetries: Int
    private let session: URLSession

    init(maxRetries: Int = 3, session: URLSession? = nil) {
        self.maxRetries = maxRetries
        if let session = session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForResource = 20
            configuration.timeoutIntervalForRequest = 20
            self.session = URLSession(configuration: configuration)
        }
    }

    func download(contentUrl: URL) async throws -> URL {
        MMNSELogger.logDebug("starting downloading with request \(contentUrl)...")

        let destinationUrl = URL.attachmentDownloadDestinationUrl(sourceUrl: contentUrl, appGroupId: nil)
        var lastError: Error?

        for attempt in 1...maxRetries {
            try Task.checkCancellation()
            do {
                let (tempUrl, _) = try await session.download(from: contentUrl)

                try Task.checkCancellation()

                let fileManager = FileManager.default
                try? fileManager.removeItem(at: destinationUrl)
                try fileManager.moveItem(at: tempUrl, to: destinationUrl)

                MMNSELogger.logDebug("finishing download successfully on attempt \(attempt)")
                return destinationUrl
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
                MMNSELogger.logDebug("download attempt \(attempt)/\(maxRetries) failed: \(error)")
                if attempt < maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(500_000_000 * attempt))
                    try Task.checkCancellation()
                }
            }
        }

        throw lastError!
    }
}
