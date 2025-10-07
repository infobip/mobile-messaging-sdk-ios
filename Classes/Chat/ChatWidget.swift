// 
//  ChatWidget.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
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
    public let multiThread: Bool?
    public let callsEnabled: Bool?
    public let themeNames: [String]?
    public let attachments: ChatWidgetAttachmentSettings
}
