// 
//  ChatAPIKeys.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

struct ChatAPIKeys {
	struct QueryParams {
		static let pushRegId = "pushRegId"
		static let widgetId = "widgetId"
        static let jwt = "jwt"
        static let theme = "theme"
		static let io = "io"
        static let domain = "domain"
        static let language = "language"
	}
	
	struct JSMessageKeys {
		static let errorCode = "errorCode"
		static let errorMessage = "errorMessage"
		static let enabled = "enabled"
        static let isVisibleControls = "isVisibleControls"
        static let attachmentUrl = "url"
        static let attachmentType = "type"
        static let attachmentCaption = "caption"
        static let additionalInfo = "additionalInfo"
	}

    struct DestinationKeys {
        static let liveChat = "liveChatDestinations"
        static let userId = "userId"
        static let applicationId = "applicationId"
    }
}
