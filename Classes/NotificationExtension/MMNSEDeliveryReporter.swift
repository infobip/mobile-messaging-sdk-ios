//
//  MMNSEDeliveryReporter.swift
//  MobileMessagingNotificationExtension
//
//  Copyright (c) 2016-2026 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

class MMNSEDeliveryReporter {
    private let applicationCode: String
    private let appGroupId: String
    private let storage: UserDefaults
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForResource = 20
        configuration.timeoutIntervalForRequest = 20
        return URLSession(configuration: configuration)
    }()

    init(applicationCode: String, appGroupId: String, storage: UserDefaults) {
        self.applicationCode = applicationCode
        self.appGroupId = appGroupId
        self.storage = storage
    }

    func report(messageIds: [String], pushRegId: String?) async throws {
        guard !messageIds.isEmpty else { return }

        MMNSELogger.logDebug("reporting delivery for message ids \(messageIds)")

        let baseUrl = resolveBaseUrl()
        let urlString = baseUrl + MMNSEConsts.API.deliveryReportPath
        guard let url = URL(string: urlString) else {
            MMNSELogger.logError("invalid delivery report URL: \(urlString)")
            throw NSError(domain: "MMNSEDeliveryReporter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20

        request.setValue("\(MMNSEConsts.APIHeaders.authorizationApiKey) \(applicationCode)", forHTTPHeaderField: MMNSEConsts.APIHeaders.authorization)
        request.setValue(calculateAppCodeHash(applicationCode), forHTTPHeaderField: MMNSEConsts.APIHeaders.applicationcode)
        request.setValue(buildUserAgent(), forHTTPHeaderField: "User-Agent")
        request.setValue("false", forHTTPHeaderField: MMNSEConsts.APIHeaders.foreground)
        request.setValue("application/json", forHTTPHeaderField: MMNSEConsts.APIHeaders.accept)
        request.setValue("application/json", forHTTPHeaderField: MMNSEConsts.APIHeaders.contentType)
        if let pushRegId = pushRegId {
            request.setValue(pushRegId, forHTTPHeaderField: MMNSEConsts.APIHeaders.pushRegistrationId)
        }
        if let installationId = storage.string(forKey: MMNSEConsts.UserDefaultsKeys.universalInstallationId) {
            request.setValue(installationId, forHTTPHeaderField: MMNSEConsts.APIHeaders.installationId)
        }

        let body: [String: Any] = [MMNSEConsts.DeliveryReport.dlrMessageIds: messageIds]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        do {
            let (_, response) = try await session.data(for: request)
            handleDynamicBaseUrl(response: response)
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCannotFindHost {
                MMNSELogger.logDebug("Cannot find host, resetting dynamic base URL")
                storage.removeObject(forKey: MMNSEConsts.DynamicBaseUrl.storedDynamicBaseUrlKey)
                storage.synchronize()
            }
            throw error
        }
    }

    // MARK: - Dynamic Base URL

    private func resolveBaseUrl() -> String {
        if let storedUrl = storage.url(forKey: MMNSEConsts.DynamicBaseUrl.storedDynamicBaseUrlKey) {
            return storedUrl.absoluteString
        }
        return MMNSEConsts.API.prodBaseURLString
    }

    private func handleDynamicBaseUrl(response: URLResponse) {
        if let httpResponse = response as? HTTPURLResponse,
           let newBaseUrlString = httpResponse.value(forHTTPHeaderField: MMNSEConsts.DynamicBaseUrl.newBaseUrlHeader),
           let newUrl = URL(string: newBaseUrlString) {
            let currentUrl = storage.url(forKey: MMNSEConsts.DynamicBaseUrl.storedDynamicBaseUrlKey)
            if newUrl != currentUrl {
                MMNSELogger.logDebug("Setting new base URL \(newUrl)")
                storage.set(newUrl, forKey: MMNSEConsts.DynamicBaseUrl.storedDynamicBaseUrlKey)
                storage.synchronize()
            }
        }
    }

    // MARK: - User Agent

    private func buildUserAgent() -> String {
        let libraryVersion = MMNSEVersion.mobileMessagingVersion
        let osVersion: String
        let deviceModel = deviceModelName()
        let appBundleId = Bundle.main.bundleIdentifier ?? ""
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let deviceName: String
        #if canImport(UIKit)
        osVersion = UIDevice.current.systemVersion
        deviceName = UIDevice.current.name
        #else
        osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        deviceName = ""
        #endif
        return "MobileMessaging/\(libraryVersion)(iOS;\(osVersion);;\(deviceModel);;\(appBundleId);\(appVersion);\(deviceName);;;)"
    }

    private func deviceModelName() -> String {
        let name = UnsafeMutablePointer<utsname>.allocate(capacity: 1)
        defer { name.deallocate() }
        uname(name)
        let machine = withUnsafePointer(to: &name.pointee.machine) { machineNamePointer -> String? in
            return machineNamePointer.withMemoryRebound(to: Int8.self, capacity: 256) { p -> String? in
                return String(validatingUTF8: p)
            }
        }
        #if canImport(UIKit)
        return machine ?? UIDevice.current.localizedModel
        #else
        return machine ?? "unknown"
        #endif
    }
}
