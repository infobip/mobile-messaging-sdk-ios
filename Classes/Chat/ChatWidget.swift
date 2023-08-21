//
//  ChatWidget.swift
//  MobileMessaging
//
//  Created by okoroleva on 24.04.2020.
//

import Foundation

public class ChatWidget {
	public let widgetId: String
	public let title: String?
	public let primaryColor: String?
	public let backgroundColor: String?
    public let maxUploadContentSize: UInt
    public let isMultithread: Bool?
    
	init?(responseJson json: JSON) {
		guard let widgetId = json[ChatAPIKeys.Widget.widgetId].string,
             let maxUploadContentSize = json[ChatAPIKeys.Widget.maxUploadContentSize].uInt else {
				return nil
		}
		self.widgetId = widgetId
		self.title = json[ChatAPIKeys.Widget.title].string
		self.primaryColor = json[ChatAPIKeys.Widget.primaryColor].string
		self.backgroundColor = json[ChatAPIKeys.Widget.backgroundColor].string
        self.maxUploadContentSize = maxUploadContentSize
        self.isMultithread = json[ChatAPIKeys.Widget.multiThread].bool
	}
}
