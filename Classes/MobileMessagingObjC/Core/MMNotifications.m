//
//  MMNotifications.m
//
//  Created by Andrey K. on 16/06/16.
//

#import <Foundation/Foundation.h>

//MARK: Notification names
NSString* MMNotificationRegistrationUpdated = @"com.mobile-messaging.notification.reg-updated";
NSString* MMNotificationDeviceTokenReceived = @"com.mobile-messaging.notification.device-token-received";
NSString* MMNotificationDeliveryReportSent = @"com.mobile-messaging.notification.dlr-sent";
NSString* MMNotificationAPIError = @"com.mobile-messaging.notification.api-error";
NSString* MMNotificationMessageReceived = @"com.mobile-messaging.notification.message-received";
NSString* MMNotificationUserSynced = @"com.mobile-messaging.notification.userdata-synced";
NSString* MMNotificationMessagesDidSend = @"com.mobile-messaging.notification.messages-did-send";
NSString* MMNotificationMessagesWillSend = @"com.mobile-messaging.notification.messages-will-send";
NSString* MMNotificationGeographicalRegionDidEnter = @"com.mobile-messaging.notification.geographical-region-did-enter";
NSString* MMNotificationGeographicalRegionDidExit = @"com.mobile-messaging.notification.geographical-region-did-exit";
NSString* MMNotificationGeoServiceDidStart = @"com.mobile-messaging.notification.geo-service-did-start";
NSString* MMNotificationMessageTapped = @"com.mobile-messaging.notification.message-tapped";
NSString* MMNotificationActionTapped = @"com.mobile-messaging.notification.action-tapped";
NSString* MMNotificationDepersonalized = @"com.mobile-messaging.notification.depersonalization-completed";
NSString* MMNotificationPersonalized = @"com.mobile-messaging.notification.personalization-completed";
NSString* MMNotificationInstallationSynced = @"com.mobile-messaging.notification.installation-synced";
NSString* MMNotificationCenterAuthRequestFinished = @"com.mobile-messaging.notification.nc-auth-request-finished";
NSString* MMNotificationInAppChatAvailabilityUpdated = @"com.mobile-messaging.notification.inappchat-availability-updated";
NSString* MMNotificationInAppChatUnreadMessagesCounterUpdated = @"com.mobile-messaging.notification.inappchat-unread-messages-counter-updated";
NSString* MMNotificationInAppChatViewChanged = @"com.mobile-messaging.notification.inappchat-view-changed";
NSString* MMNotificationChatRegistrationReceived = @"com.mobile-messaging.notification.livechat-registration-received";


//MARK: Notification keys
NSString* MMNotificationKeyRegistrationInternalId = @"com.mobile-messaging.notification.key.registration";
NSString* MMNotificationKeyDeviceToken = @"com.mobile-messaging.notification.key.device-token";
NSString* MMNotificationKeyDLRMessageIDs = @"com.mobile-messaging.notification.key.dlr-message-ids";
NSString* MMNotificationKeyAPIErrorUserInfo = @"com.mobile-messaging.notification.key.api-error";

NSString* MMNotificationKeyMessage = @"com.mobile-messaging.notification.key.message";
NSString* MMNotificationKeyNotificationUserInfo = @"com.mobile-messaging.notification.key.notification-user-info";

NSString* MMNotificationKeyActionIdentifier = @"com.mobile-messaging.notification.key.action-identifier";
NSString* MMNotificationKeyActionTextInput = @"com.mobile-messaging.notification.key.text-input";

NSString* MMNotificationKeyMessagePayload = @"com.mobile-messaging.notification.key.messagePayload";
NSString* MMNotificationKeyMessageCustomPayload = @"com.mobile-messaging.notification.key.message-custom-payload";
NSString* MMNotificationKeyMessageIsPush = @"com.mobile-messaging.notification.key.message-is-push";
NSString* MMNotificationKeyMessageIsSilent = @"com.mobile-messaging.notification.key.message-is-silent";

NSString* MMNotificationKeyMessageSendingMOMessages = @"com.mobile-messaging.notification.key.message-sending-messages";
NSString* MMNotificationKeyGeographicalRegion = @"com.mobile-messaging.notification.key.geographical-region";
NSString* MMNotificationKeyMobileMessagingContext = @"com.mobile-messaging.notification.key.mobile-messaging-context";
NSString* MMNotificationKeyIsPrimaryDevice = @"com.mobile-messaging.notification.key.is_primary_device";
NSString* MMNotificationKeyUser = @"com.mobile-messaging.notification.key.user";
NSString* MMNotificationKeyInstallation = @"com.mobile-messaging.notification.key.installation";
NSString* MMNotificationKeyGranted = @"com.mobile-messaging.notification.key.granted";
NSString* MMNotificationKeyError = @"com.mobile-messaging.notification.key.error";
NSString* MMNotificationKeyInAppChatEnabled = @"com.mobile-messaging.notification.inappchat-enabled";
NSString* MMNotificationKeyInAppChatUnreadMessagesCounter = @"com.mobile-messaging.notification.key.inappchat-unread-messages-counter";
NSString* MMNotificationKeyInAppChatViewChanged = @"com.mobile-messaging.notification.key.inappchat-view-state-changed";
NSString* MMNotificationKeyChatRegistrationReceived = @"com.mobile-messaging.notification.key.livechat-registration-received";
