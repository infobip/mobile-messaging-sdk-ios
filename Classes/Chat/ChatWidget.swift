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
    public let callsEnabled: Bool?
    public let themeNames: [String]

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
        self.callsEnabled = json[ChatAPIKeys.Widget.callsEnabled].bool
        let jsonThemes = json[ChatAPIKeys.Widget.themeNames].arrayValue
        var stringThemes: [String] = []
        for jsonTheme in jsonThemes {
            if let theme = jsonTheme.string {
                stringThemes.append(theme)
            }
        }
        self.themeNames = stringThemes
	}
}
