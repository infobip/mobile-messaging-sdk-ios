//
//  ChatAttachment.swift
//  MobileMessaging
//
//  Created by Olga Koroleva on 24.08.2020.
//

import Foundation

class ChatMobileAttachment: ChatBaseAttachment {
    let base64: String
    let mimeType: String
    
    init(_ name: String? = nil, data: Data) {
        self.base64 = data.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
        self.mimeType = ChatAttachmentUtils.mimeType(forData: data)
        let fileName = name ?? UUID().uuidString
        
        guard let fileExtension = ChatAttachmentUtils.fileExtension(forData: data) else {
            super.init(fileName: fileName)
            return
        }
        super.init(fileName: name ?? (fileName  + "." + fileExtension))
    }
    
    func base64UrlString() -> String {
        return "data:\(self.mimeType);base64,\(self.base64)"
    }
}

class ChatWebAttachment: ChatBaseAttachment {
    let url: URL
    let type: ChatAttachmentType
    init?(url: URL, typeString: String, fileName: String?) {
        guard let type = ChatAttachmentType(rawValue: typeString) else {
            MMLogDebug("[InAppChat] type \(typeString) not supported")
            return nil
        }
        self.url = url
        self.type = type
        super.init(fileName: fileName)
    }
}

enum ChatAttachmentType: String {
    case image = "IMAGE"
    case video = "VIDEO"
    case document = "DOCUMENT"
}

class ChatBaseAttachment {
    let fileName: String?
    init(fileName: String?) {
        self.fileName = fileName
    }
}
