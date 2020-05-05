//
//  ChatWidget.swift
//  MobileMessaging
//
//  Created by okoroleva on 24.04.2020.
//

import Foundation

class ChatWidget {
	let widgetId: String
	let title: String?
	let primaryColor: String?
	let backgroundColor: String?
	init?(responseJson json: JSON) {
		guard let widgetId = json[ChatAPIKeys.Widget.widgetId].string else {
				return nil
		}
		self.widgetId = widgetId
		self.title = json[ChatAPIKeys.Widget.title].string
		self.primaryColor = json[ChatAPIKeys.Widget.primaryColor].string
		self.backgroundColor = json[ChatAPIKeys.Widget.backgroundColor].string
	}
}
