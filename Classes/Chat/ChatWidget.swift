//
//  ChatWidget.swift
//  MobileMessaging
//
//  Created by okoroleva on 24.04.2020.
//

import Foundation

public struct ChatWidgetAttachmentSettings: Decodable {
    public let maxSize: UInt
    public let isEnabled: Bool
    public let allowedExtensions: [String]
}

public struct ChatWidget: Decodable {
	public let id: String
	public let title: String?
	public let primaryColor: String?
    public let primaryTextColor: String?
	public let backgroundColor: String?
    public let isMultithread: Bool?
    public let callsEnabled: Bool?
    public let themeNames: [String]
    public let attachments: ChatWidgetAttachmentSettings
}
