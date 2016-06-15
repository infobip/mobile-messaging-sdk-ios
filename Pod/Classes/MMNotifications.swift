//
//  MMNotifications.swift
//  Pods
//
//  Created by Andrey K. on 15/06/16.
//
//


//MARK: Notifications

/**
Posted when the registration is updated on backend server.
*/
public let MMNotificationRegistrationUpdated = "com.mobile-messaging.notification.reg-updated"

/**
Posted when an APNs device token is received.
*/
public let MMNotificationDeviceTokenReceived = "com.mobile-messaging.notification.device-token-received"

/**
Posted when the library has succesfully sent message delivery report.
*/
public let MMNotificationDeliveryReportSent = "com.mobile-messaging.notification.dlr-sent"

/**
Posted when a server error received.
*/
public let MMNotificationAPIError = "com.mobile-messaging.notification.api-error"

/**
Posted when a message is received (either pushed by APNs or fetched from the server).
*/
public let MMNotificationMessageReceived = "com.mobile-messaging.notification.message-received"


//MARK: Notification keys

/**
Key for entry in userInfo dictionary of `kRegistrationUpdated` notification.
Contains an Internal Id string for the registered user.
*/
public let MMNotificationKeyRegistrationInternalId = "com.mobile-messaging.notification.registration-key"

/**
Key for entry in userInfo dictionary of `kRegistrationUpdated` notification.
Contains a hex-encoded device token string received from APNS.
*/
public let MMNotificationKeyDeviceToken = "com.mobile-messaging.notification.device-token-key"

/**
Key for entry in userInfo dictionary of `kDeliveryReportSent` notification.
Contains a an array of message ID strings.
*/
public let MMNotificationKeyDLRMessageIDs = "com.mobile-messaging.notification.dlr-key"

/**
Key for entry in userInfo dictionary of `kAPIError` notification.
Contains a corresponding `NSError` object.
*/
public let MMNotificationKeyAPIErrorUserInfo = "com.mobile-messaging.notification.api-error-key"

/**
Key for entry in userInfo dictionary of `kMessageReceived` notification.
Contains a remote notification payload.
*/
public let MMNotificationKeyMessagePayload = "com.mobile-messaging.notification.message-key"

/**
Key for entry in userInfo dictionary of `kMessageReceived` notification.
Contains a flag that indicates whether the message is pushed by APNs or pulled from the server.
*/
public let MMNotificationKeyMessageIsPush = "com.mobile-messaging.notification.message-is-push-key"

/**
Key for entry in userInfo dictionary of `kMessageReceived` notification.
Contains a flag that indicates whether the remote notification is a silent push.
*/
public let MMNotificationKeyMessageIsSilent = "com.mobile-messaging.notification.message-is-silent-key"