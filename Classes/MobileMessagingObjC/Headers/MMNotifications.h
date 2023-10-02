//
//  MMNotifications.h
//
//  Created by Andrey K. on 16/06/16.
//


//MARK: Notification names

/**
 Posted after the registration is updated on backend server.
 */
FOUNDATION_EXPORT NSString* MMNotificationRegistrationUpdated;

/**
 Posted after an APNs device token is received.
 */
FOUNDATION_EXPORT NSString* MMNotificationDeviceTokenReceived;

/**
 Posted after the library has succesfully sent message delivery report.
 */
FOUNDATION_EXPORT NSString* MMNotificationDeliveryReportSent;

/**
 Posted after a server error received.
 */
FOUNDATION_EXPORT NSString* MMNotificationAPIError;

/**
 Posted after a message is received (either pushed by APNs or fetched from the server).
 */
FOUNDATION_EXPORT NSString* MMNotificationMessageReceived;

/**
 Posted after the user data is synced with the server.
 */
FOUNDATION_EXPORT NSString* MMNotificationUserSynced;

/**
 Posted after the mobile originated message sent to the server. The `userInfo` dictionary contains the following key: `MMNotificationKeyMessageSendingMOMessages` - contains an array of `MM_MOMessage` messages with `status` of sending.
 */
FOUNDATION_EXPORT NSString* MMNotificationMessagesDidSend;

/**
 Posted when the mobile originated message is about to send to the server. The `userInfo` dictionary contains the following key: `MMNotificationKeyMessageSendingMOMessages` - contains an array of `MM_MOMessage` messages with `status` of sending.
 */
FOUNDATION_EXPORT NSString* MMNotificationMessagesWillSend;

/**
 Posted after the user enters monitored region. The `userInfo` dictionary contains the following key: `MMNotificationKeyGeographicalRegion` - contains `MMRegion` object in which user entered.
 */
FOUNDATION_EXPORT NSString* MMNotificationGeographicalRegionDidEnter;

/**
 Posted after the user exits monitored region. The `userInfo` dictionary contains the following key: `MMNotificationKeyGeographicalRegion` - contains `MMRegion` object from which user exited.
 */
FOUNDATION_EXPORT NSString* MMNotificationGeographicalRegionDidExit;

/**
 Posted after the Geofencing Service started.
 */
FOUNDATION_EXPORT NSString* MMNotificationGeoServiceDidStart;

/**
 Posted after the User tapped notification.
 */
FOUNDATION_EXPORT NSString* MMNotificationMessageTapped;

/**
 Posted after the User tapped performed notification action.
 */
FOUNDATION_EXPORT NSString* MMNotificationActionTapped;

/**
 Posted after the depersonalization operation completes on server.
 */
FOUNDATION_EXPORT NSString* MMNotificationDepersonalized;

/**
 Posted after the personalization operation completes on server.
 */
FOUNDATION_EXPORT NSString* MMNotificationPersonalized;

/**
 Posted after the current installation synced with the server.
 */
FOUNDATION_EXPORT NSString* MMNotificationInstallationSynced;

/**
 Posted after `UNUserNotificationCenter.requestAuthorization` completed.
 */
FOUNDATION_EXPORT NSString* MMNotificationCenterAuthRequestFinished;

/**
 Posted after the in-app chat availability status received from backend server.
 */
FOUNDATION_EXPORT NSString* MMNotificationInAppChatAvailabilityUpdated;

/**
 Posted after the in-app chat messages counter updated. The `userInfo` dictionary contains the following key: `MMNotificationKeyInAppChatUnreadMessagesCounter` - with `Int` number.
 */
FOUNDATION_EXPORT NSString* MMNotificationInAppChatUnreadMessagesCounterUpdated;

/**
 Posted after the in-app chat view changes. The `userInfo` dictionary contains the following key: `MMNotificationKeyInAppChatViewChanged` - with `String` readable value from MMChatWebViewState.
 */
FOUNDATION_EXPORT NSString* MMNotificationInAppChatViewChanged;

/**
 Posted after the LiveChat registration has been received. The `userInfo` dictionary contains the following key: `MMNotificationKeyChatRegistrationReceived` - with `String` readable value for the registrationId.
 */
FOUNDATION_EXPORT NSString* MMNotificationChatRegistrationReceived;

//MARK: Notification keys

/**
 Key for entry in userInfo dictionary of `MMNotificationRegistrationUpdated` notification.
 Contains an Internal Id string for the registered user.
 */
FOUNDATION_EXPORT NSString* MMNotificationKeyRegistrationInternalId;

/**
 Key for entry in userInfo dictionary of `MMNotificationKeyDeviceToken` notification.
 Contains a hex-encoded device token string received from APNS.
 */
FOUNDATION_EXPORT NSString* MMNotificationKeyDeviceToken;

/**
 Key for entry in userInfo dictionary of `MMNotificationDeliveryReportSent` notification.
 Contains a an array of message ID strings.
 */
FOUNDATION_EXPORT NSString* MMNotificationKeyDLRMessageIDs;

/**
 Key for entry in userInfo dictionary of `MMNotificationAPIError` notification.
 Contains a corresponding `NSError` object.
 */
FOUNDATION_EXPORT NSString* MMNotificationKeyAPIErrorUserInfo;

/**
 Key for entry in userInfo dictionary of `MMNotificationMessageTapped`, `MMNotificationActionTapped`, `MMNotificationMessageReceived` notification.
 Contains an `MM_MTMessage` object.
 */
FOUNDATION_EXPORT NSString* MMNotificationKeyMessage;

/**
 Key for entry in userInfo dictionary of `MMNotificationMessageTapped`, `MMNotificationActionTapped` notification.
 Contains an original notification userInfo.
 */
FOUNDATION_EXPORT NSString* MMNotificationKeyNotificationUserInfo;

/**
 Key for entry in userInfo dictionary of `MMNotificationMessageTapped`, `MMNotificationActionTapped` notification.
 Contains an action identifier string.
 */
FOUNDATION_EXPORT NSString* MMNotificationKeyActionIdentifier;

/**
 Key for entry in userInfo dictionary of `MMNotificationActionTapped` notification.
 Contains text that has been entered into the text input.
 */
FOUNDATION_EXPORT NSString* MMNotificationKeyActionTextInput;

/**
 Key for entry in userInfo dictionary of `MMNotificationMessagesWillSend` and `MMNotificationMessagesDidSend` notification.
 Contains an array of `MM_MOMessage` messages with `status` of sending.
 */
FOUNDATION_EXPORT NSString* MMNotificationKeyMessageSendingMOMessages;

/**
 Key for entry in userInfo dictionary of `MMNotificationGeographicalRegionDidEnter` and `MMNotificationGeographicalRegionDidExit` notification.
 Contains object holding info about region to which user entered or exited.
 */
FOUNDATION_EXPORT NSString* MMNotificationKeyGeographicalRegion;

/**
 Key for entry in userInfo dictionary of `MMNotificationUserSynced` notification.
 Contains a current user data.
 */
FOUNDATION_EXPORT NSString* MMNotificationKeyUser;

/**
 Key for entry in userInfo dictionary of `MMNotificationInstallationSynced` notification.
 Contains a current installation data.
 */
FOUNDATION_EXPORT NSString* MMNotificationKeyInstallation;

/**
 Key name for `granted` boolean. See MMNotificationCenterAuthRequestFinished.
 */
FOUNDATION_EXPORT NSString* MMNotificationKeyGranted;

/**
 Key name for optional `error` object. See MMNotificationCenterAuthRequestFinished.
 */
FOUNDATION_EXPORT NSString* MMNotificationKeyError;

/**
 Key for entry in userInfo dictionary of `MMNotificationInAppChatAvailabilityUpdated` notification.
 Value is boolean, chat can be enabled or not.
 */
FOUNDATION_EXPORT NSString* MMNotificationKeyInAppChatEnabled;

/**
 Key for entry in userInfo dictionary of `MMNotificationInAppChatUnreadMessagesCounterUpdated` notification.
 Contatins an Int value.
 */
FOUNDATION_EXPORT NSString* MMNotificationKeyInAppChatUnreadMessagesCounter;

/**
 Key for entry in userInfo dictionary of `MMNotificationInAppChatViewChanged` notification.
 Contatins an Int value.
 */
FOUNDATION_EXPORT NSString* MMNotificationKeyInAppChatViewChanged;

/**
 Key for entry in userInfo dictionary of `MMNotificationKeyChatRegistrationReceived` notification.
 Contatins a String value.
 */
FOUNDATION_EXPORT NSString* MMNotificationKeyChatRegistrationReceived;
