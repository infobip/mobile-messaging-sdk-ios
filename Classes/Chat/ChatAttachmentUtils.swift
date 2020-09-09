//
//  ChatAttachmentUtils.swift
//  MobileMessaging
//
//  Created by Olga Koroleva on 03.07.2020.
//

import Foundation
import MobileCoreServices

class ChatAttachmentUtils: NamedLogger {
    static let DefaultMaxAttachmentSize: UInt = 10*1024*1024
    static func mimeType(forData data: Data) -> String {
        var result = "application/octet-stream"
        if let mimeType = Swime.mimeType(data: data)?.mime {
            result = mimeType
        }
        return result
    }
    
    static func fileExtension(forData data: Data) -> String? {
        return Swime.mimeType(data: data)?.ext
    }
    
    static func mimeType(forPathExtension pathExtension: String) -> String? {
        guard let uti: CFString = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as NSString, nil)?.takeRetainedValue(),
              let mimeType: CFString = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() else {
            return nil
        }

        return mimeType as String
    }
    
    static func isInfoPlistKeyDefined(_ key: String) -> Bool {
        let result = ((Bundle.main.infoDictionary?.index(forKey: key)) != nil)
        if !result {
            logWarn("\(key) isn't defined in info.plist")
        }
        return result
    }
}
