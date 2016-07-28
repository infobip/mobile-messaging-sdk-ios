//
//  MMNotifications.h
//
//  Created by Andrey K. on 16/06/16.
//


//MARK: Notification names

/**
 Posted when the registration is updated on backend server.
 */
FOUNDATION_EXPORT NSString* MMNotificationRegistrationUpdated;

/**
 Posted when an APNs device token is received.
 */
FOUNDATION_EXPORT NSString* MMNotificationDeviceTokenReceived;

/**
 Posted when the library has succesfully sent message delivery report.
 */
FOUNDATION_EXPORT NSString* MMNotificationDeliveryReportSent;

/**
 Posted when a server error received.
 */
FOUNDATION_EXPORT NSString* MMNotificationAPIError;

/**
 Posted when a message is received (either pushed by APNs or fetched from the server).
 */
FOUNDATION_EXPORT NSString* MMNotificationMessageReceived;

/**
 Posted when the user data is synced with the server.
 */
FOUNDATION_EXPORT NSString* MMNotificationUserDataSynced;

/**
 Posted when the mobile originated message sent to the server. The `userInfo` dictionary contains the following key: `MMNotificationKeyMessageSendingMOMessages` - contains an array of `MOMessage` messages with `status` of sending.
 */
FOUNDATION_EXPORT NSString* MMNotificationMessagesDidSend;

/**
 Posted when the mobile originated message is about to send to the server. The `userInfo` dictionary contains the following key: `MMNotificationKeyMessageSendingMOMessages` - contains an array of `MOMessage` messages with `status` of sending.
 */
FOUNDATION_EXPORT NSString* MMNotificationMessagesWillSend;

/**
 Posted when the user enters monitored region. The `userInfo` dictionary contains the following key: `MMNotificationKeyGeographicalRegion` - contains `MMRegion` object in which user entered.
 */
FOUNDATION_EXPORT NSString* MMNotificationGeographicalRegionDidEnter;

/**
 Posted when the user exits monitored region. The `userInfo` dictionary contains the following key: `MMNotificationKeyGeographicalRegion` - contains `MMRegion` object from which user exited.
 */
FOUNDATION_EXPORT NSString* MMNotificationGeographicalRegionDidExit;


//MARK: Notification keys

/**
 Key for entry in userInfo dictionary of `kRegistrationUpdated` notification.
 Contains an Internal Id string for the registered user.
 */
FOUNDATION_EXPORT NSString* MMNotificationKeyRegistrationInternalId;

/**
 Key for entry in userInfo dictionary of `kRegistrationUpdated` notification.
 Contains a hex-encoded device token string received from APNS.
 */
FOUNDATION_EXPORT NSString* MMNotificationKeyDeviceToken;

/**
 Key for entry in userInfo dictionary of `kDeliveryReportSent` notification.
 Contains a an array of message ID strings.
 */
FOUNDATION_EXPORT NSString* MMNotificationKeyDLRMessageIDs;

/**
 Key for entry in userInfo dictionary of `kAPIError` notification.
 Contains a corresponding `NSError` object.
 */
FOUNDATION_EXPORT NSString* MMNotificationKeyAPIErrorUserInfo;

/**
 Key for entry in userInfo dictionary of `kMessageReceived` notification.
 Contains a remote notification payload.
 */
FOUNDATION_EXPORT NSString* MMNotificationKeyMessagePayload;

/**
 Key for entry in userInfo dictionary of `kMessageReceived` notification.
 Contains a remote notification custom parameters from payload.
 */
FOUNDATION_EXPORT NSString* MMNotificationKeyMessageCustomPayload;

/**
 Key for entry in userInfo dictionary of `kMessageReceived` notification.
 Contains a flag that indicates whether the message is pushed by APNs or pulled from the server.
 */
FOUNDATION_EXPORT NSString* MMNotificationKeyMessageIsPush;

/**
 Key for entry in userInfo dictionary of `kMessageReceived` notification.
 Contains a flag that indicates whether the remote notification is a silent push.
 */
FOUNDATION_EXPORT NSString* MMNotificationKeyMessageIsSilent;

/**
 Key for entry in userInfo dictionary of `MMNotificationMessagesWillSend` and `MMNotificationMessagesDidSend` notification.
 Contains a an array of `MOMessage` messages with `status` of sending.
 */
FOUNDATION_EXPORT NSString* MMNotificationKeyMessageSendingMOMessages;

/**
 Key for entry in userInfo dictionary of `MMNotificationGeoRegionDidEnter` and `MMNotificationGeoRegionDidExit` notification.
 Contains object holding info about region to which user entered or exited.
 */
FOUNDATION_EXPORT NSString* MMNotificationKeyGeographicalRegion;
