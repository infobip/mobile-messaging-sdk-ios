//
//  MMNSEUtils.swift
//  MobileMessagingNotificationExtension
//
//  Copyright (c) 2016-2026 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import CommonCrypto

extension Bundle {
    static var mainAppBundle: Bundle {
        var bundle = Bundle.main
        if bundle.bundleURL.pathExtension == "appex" {
            // Peel off two directory levels - MY_APP.app/PlugIns/MY_APP_EXTENSION.appex
            let url = bundle.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
            if let otherBundle = Bundle(url: url) {
                bundle = otherBundle
            }
        }
        return bundle
    }

    var appGroupId: String? {
        return self.object(forInfoDictionaryKey: MMNSEConsts.InfoPlistKeys.appGroupId) as? String
    }
}

extension String {
    func sha256() -> String {
        guard let data = self.data(using: .utf8, allowLossyConversion: true) else { return "" }

        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { bufferPtr in
            _ = CC_SHA256(bufferPtr.baseAddress, CC_LONG(data.count), &hash)
        }

        return hash.map { String(format: "%02x", $0) }.joined()
    }

    var safeUrl: URL? {
        return URL(string: self)
    }
}

extension URL {
    // NOTE: Duplicated in MMUtils.swift in MobileMessaging module. Any changes here must be mirrored there.
    static func attachmentDownloadDestinationFolderUrl(appGroupId: String?) -> URL {
        let fileManager = FileManager.default
        let tempFolderUrl: URL
        if let appGroupId = appGroupId, let appGroupContainerUrl = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) {
            tempFolderUrl = appGroupContainerUrl.appendingPathComponent("Library/Caches")
        } else {
            tempFolderUrl = URL(fileURLWithPath: NSTemporaryDirectory())
        }

        var destinationFolderURL = tempFolderUrl.appendingPathComponent("com.mobile-messaging.rich-notifications-attachments", isDirectory: true)

        var isDir: ObjCBool = true
        if !fileManager.fileExists(atPath: destinationFolderURL.path, isDirectory: &isDir) {
            do {
                try fileManager.createDirectory(at: destinationFolderURL, withIntermediateDirectories: true, attributes: nil)
            } catch _ {
                destinationFolderURL = tempFolderUrl
            }
        }
        return destinationFolderURL
    }

    static func attachmentDownloadDestinationUrl(sourceUrl: URL, appGroupId: String?) -> URL {
        return URL.attachmentDownloadDestinationFolderUrl(appGroupId: appGroupId).appendingPathComponent(sourceUrl.absoluteString.sha256() + "." + sourceUrl.pathExtension)
    }
}

func calculateAppCodeHash(_ appCode: String) -> String {
    return String(appCode.sha256().prefix(10))
}
