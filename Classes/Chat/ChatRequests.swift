//
//  ChatRequests.swift
//  MobileMessaging
//
//  Created by okoroleva on 24.04.2020.
//

import Foundation

class GetWidgetRequest: GetRequest {
	typealias ResponseType = GetChatWidgetResponse

	init(applicationCode: String, pushRegistrationId: String?) {
		super.init(applicationCode: applicationCode, path: .ChatWidget, pushRegistrationId: pushRegistrationId, parameters: nil)
	}
}

typealias GetChatWidgetResult = MMResult<GetChatWidgetResponse>

struct GetChatWidgetResponse {
	let widget: ChatWidget?
}

extension GetChatWidgetResponse: JSONDecodable {
	init?(json value: JSON) {
		guard let widget = ChatWidget(responseJson: value) else {
			return nil
		}
		self.widget = widget
	}
}

extension RemoteAPIProvider {
    func getChatWidget(applicationCode: String, pushRegistrationId: String?, queue: DispatchQueue, completion: @escaping (GetChatWidgetResult) -> Void) {
		let request = GetWidgetRequest(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId)
        performRequest(request: request, queue: queue, completion: completion)
	}
}
