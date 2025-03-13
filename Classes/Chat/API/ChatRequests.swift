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

class MMGetChatRegistrationsRequest: GetRequest {
    typealias ResponseType = MMGetChatRegistrationsResult

    init(applicationCode: String, pushRegistrationId: String, baseURLString: String? = nil) {
        var baseURL: URL?
        if let baseURLString = baseURLString {
            baseURL = URL(string: baseURLString)
        }
        super.init(applicationCode: applicationCode, accessToken: nil, path: .LiveChatInfo,
                   pushRegistrationId: pushRegistrationId,
                   pathParameters: ["{pushRegistrationId}": pushRegistrationId],
                   baseUrl: baseURL)
    }
}

public typealias MMGetChatRegistrationsResult = MMResult<MMGetChatRegistrationsResponse>

public struct MMGetChatRegistrationsResponse {
    public let chatRegistrations: [String: String]
}

extension MMGetChatRegistrationsResponse: JSONDecodable {
    public init?(json value: JSON) {
        var registrations: [String: String] = [:]
        for livechat in value[ChatAPIKeys.DestinationKeys.liveChat].arrayValue {
            if let widgetId = livechat[ChatAPIKeys.DestinationKeys.applicationId].string,
               let registrationId = livechat[ChatAPIKeys.DestinationKeys.userId].string
            {
                registrations[widgetId] = registrationId
            }
        }

        self.chatRegistrations = registrations
    }
}

extension RemoteAPIProvider {
    public func getChatWidget(applicationCode: String, pushRegistrationId: String?, queue: DispatchQueue, completion: @escaping (GetChatWidgetResult) -> Void) {
		let request = GetWidgetRequest(
            applicationCode: applicationCode,
            pushRegistrationId: pushRegistrationId)
        performRequest(
            request: request, 
            queue: queue,
            completion: completion)
	}

    public func getChatRegistrations(
        applicationCode: String,
        pushRegistrationId: String?,
        baseURL: String? = nil,
        queue: DispatchQueue,
        completion: @escaping (MMGetChatRegistrationsResult) -> Void)
    {
        guard let pushRegId = pushRegistrationId else {
            completion(.Cancel)
            return
        }
        let request = MMGetChatRegistrationsRequest(
            applicationCode: applicationCode,
            pushRegistrationId: pushRegId)
        queue.async {
            MobileMessaging.sharedInstance?.remoteApiProvider.performRequest(
                request: request, 
                queue: queue,
                completion: completion)
        }
    }
}
