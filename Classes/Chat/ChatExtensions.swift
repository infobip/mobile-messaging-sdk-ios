//
//  Utils.swift
//  MobileMessaging
//
//  Created by Olga Koroleva on 16.05.2022.
//

import Foundation
import UIKit

extension UIImage {
    convenience init?(mm_chat_named: String) {
        self.init(named: mm_chat_named, in: MMInAppChatService.resourceBundle, compatibleWith: nil)
    }
}
