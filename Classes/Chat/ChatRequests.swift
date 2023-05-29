//
//  ChatRequests.swift
//  MobileMessaging
//
//  Created by okoroleva on 24.04.2020.
//

import Foundation

public class GetWidgetRequest: GetRequest {
	typealias ResponseType = GetChatWidgetResponse

	init(applicationCode: String, pushRegistrationId: String?) {
		super.init(applicationCode: applicationCode, path: .ChatWidget, pushRegistrationId: pushRegistrationId, parameters: nil)
	}
}

public typealias GetChatWidgetResult = MMResult<GetChatWidgetResponse>

public struct GetChatWidgetResponse {
	public let widget: ChatWidget?
}

extension GetChatWidgetResponse: JSONDecodable {
    public init?(json value: JSON) {
		guard let widget = ChatWidget(responseJson: value) else {
			return nil
		}
		self.widget = widget
	}
}

extension RemoteAPIProvider {
    public func getChatWidget(applicationCode: String, pushRegistrationId: String?, queue: DispatchQueue, completion: @escaping (GetChatWidgetResult) -> Void) {
		let request = GetWidgetRequest(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId)
        performRequest(request: request, queue: queue, completion: completion)
	}
}
