//
//  ChatAPIKeys.swift
//  MobileMessaging
//
//  Created by okoroleva on 29.04.2020.
//

import Foundation

struct ChatAPIKeys {
	struct Widget {
		static let widgetId = "id"
		static let title = "title"
		static let primaryColor = "primaryColor"
		static let backgroundColor = "backgroundColor"
        static let maxUploadContentSize = "maxUploadContentSize"
        static let multiThread = "multiThread"
	}
	struct QueryParams {
		static let pushRegId = "pushRegId"
		static let widgetId = "widgetId"
        static let jwt = "jwt"
		static let io = "io"
	}
	
	struct JSMessageKeys {
		static let errorCode = "errorCode"
		static let errorMessage = "errorMessage"
		static let enabled = "enabled"
        static let isVisibleControls = "isVisibleControls"
        static let attachmentUrl = "url"
        static let attachmentType = "type"
        static let attachmentCaption = "caption"
	}
}
