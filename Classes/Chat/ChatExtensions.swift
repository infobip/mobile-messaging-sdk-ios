// 
//  ChatExtensions.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import UIKit

extension UIImage {
    convenience init?(mm_chat_named: String) {
        self.init(named: mm_chat_named, in: MMInAppChatService.resourceBundle, compatibleWith: nil)
    }
}
