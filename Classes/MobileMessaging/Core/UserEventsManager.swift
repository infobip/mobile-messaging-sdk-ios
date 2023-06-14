//
//  UserEventsManager.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 17/01/2019.
//


import Foundation

public class UserEventsManager {

	class func postApiErrorEvent(_ error: NSError?) {
		if let error = error {
			post(MMNotificationAPIError, [MMNotificationKeyAPIErrorUserInfo: error])
		}
	}

	class func postRegUpdatedEvent(_ pushRegId: String?) {
		if let pushRegId = pushRegId {
			post(MMNotificationRegistrationUpdated, [MMNotificationKeyRegistrationInternalId: pushRegId])
		}
	}

	class func postDepersonalizedEvent() {
		post(MMNotificationDepersonalized)
	}

	class func postPersonalizedEvent() {
		post(MMNotificationPersonalized)
	}

	class func postUserSyncedEvent(_ user: MMUser?) {
		if let user = user {
			post(MMNotificationUserSynced, [MMNotificationKeyUser: user])
		}
	}

	class func postMessageReceivedEvent(_ message: MM_MTMessage) {
		post(MMNotificationMessageReceived, [MMNotificationKeyMessage: message])
	}

	class func postInstallationSyncedEvent(_ installation: MMInstallation?) {
		if let installation = installation {
			post(MMNotificationInstallationSynced, [MMNotificationKeyInstallation: installation])
		}
	}

	class func postDLRSentEvent(_ messageIds: [String]) {
		if !messageIds.isEmpty {
			post(MMNotificationDeliveryReportSent, [MMNotificationKeyDLRMessageIDs: messageIds])
		}
	}

	class func postWillSendMessageEvent(_ messagesToSend: Array<MM_MOMessage>) {
		if !messagesToSend.isEmpty {
			post(MMNotificationMessagesWillSend, [MMNotificationKeyMessageSendingMOMessages: messagesToSend])
		}
	}

	class func postMessageSentEvent(_ messages: [MM_MOMessage]) {
		if !messages.isEmpty {
			post(MMNotificationMessagesDidSend, [MMNotificationKeyMessageSendingMOMessages: messages])
		}
	}

	class func postDeviceTokenReceivedEvent(_ tokenStr: String) {
		post(MMNotificationDeviceTokenReceived, [MMNotificationKeyDeviceToken: tokenStr])
	}

	class func postMessageTappedEvent(_ userInfo: [String: Any]) {
		post(MMNotificationMessageTapped, userInfo)
	}

	class func postActionTappedEvent(_ userInfo: [String: Any]) {
		post(MMNotificationActionTapped, userInfo)
	}

	public class func postGeoServiceStartedEvent() {
		post(MMNotificationGeoServiceDidStart)
	}

	class func postNotificationCenterAuthRequestFinished(granted: Bool, error: Error?) {
		var userInfo: [String: Any] = [MMNotificationKeyGranted: granted]
		if let error = error {
			userInfo[MMNotificationKeyError] = error
		}
		post(MMNotificationCenterAuthRequestFinished, userInfo)
	}

    public class func post(_ name: String, _ userInfo: [String: Any]? = nil) {
        DispatchQueue.main.async {
			NotificationCenter.default.post(name: NSNotification.Name(rawValue: name), object: self, userInfo: userInfo)
		}
	}
}
