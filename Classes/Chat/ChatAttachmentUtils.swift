//
//  ChatAttachmentUtils.swift
//  MobileMessaging
//
//  Created by Olga Koroleva on 03.07.2020.
//

import Foundation
import MobileCoreServices
import Photos

class ChatAttachmentUtils: NamedLogger {
    static let DefaultMaxAttachmentSize: UInt = 10*1024*1024 // 10Mb
    static let DefaultMaxTextLength: UInt = 1024*4 // 4096 chars
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


    @available(iOS 14.0, *)
    static func convertToUTType(_ allowedContentTypes: [String]) -> [UTType] {
        var contentTypes: [UTType] = []
        for typeExtension in allowedContentTypes {
            if let uType = UTType(filenameExtension: typeExtension) {
                contentTypes.append(uType)
            }
        }
        return contentTypes
    }

    static func isCameraNeeded(for allowedContentTypes: [String]) -> Bool {
        let videoExtensions: Set<String> = ["mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "mpeg", "mpg", "m4v", "3gp", "ogv", "ts", "vob", "rm", "rmvb", "divx", "asf", "m2ts", "srt"]

        let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "svg", "ico", "heic", "heif", "raw", "cr2", "nef", "arw", "dng", "psd"]

        let allowedVideoTypes = Set(allowedContentTypes).intersection(videoExtensions)
        let alloweImagesTypes =  Set(allowedContentTypes).intersection(imageExtensions)
        return !(allowedVideoTypes.isEmpty && alloweImagesTypes.isEmpty)
    }
}
