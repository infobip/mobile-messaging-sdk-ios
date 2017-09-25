//
//  MMNotifications.m
//
//  Created by Andrey K. on 16/06/16.
//

//MARK: Notification names
NSString* MMNotificationRegistrationUpdated = @"com.mobile-messaging.notification.reg-updated";
NSString* MMNotificationDeviceTokenReceived = @"com.mobile-messaging.notification.device-token-received";
NSString* MMNotificationDeliveryReportSent = @"com.mobile-messaging.notification.dlr-sent";
NSString* MMNotificationAPIError = @"com.mobile-messaging.notification.api-error";
NSString* MMNotificationMessageReceived = @"com.mobile-messaging.notification.message-received";
NSString* MMNotificationUserDataSynced = @"com.mobile-messaging.notification.userdata-synced";
NSString* MMNotificationMessagesDidSend = @"com.mobile-messaging.notification.messages-did-send";
NSString* MMNotificationMessagesWillSend = @"com.mobile-messaging.notification.messages-will-send";
NSString* MMNotificationGeographicalRegionDidEnter = @"com.mobile-messaging.notification.geographical-region-did-enter";
NSString* MMNotificationGeographicalRegionDidExit = @"com.mobile-messaging.notification.geographical-region-did-exit";
NSString* MMNotificationGeoServiceDidStart = @"com.mobile-messaging.notification.geo-service-did-start";
NSString* MMNotificationMessageTapped = @"com.mobile-messaging.notification.message-tapped";

//MARK: Notification keys
NSString* MMNotificationKeyRegistrationInternalId = @"com.mobile-messaging.notification.key.registration";
NSString* MMNotificationKeyDeviceToken = @"com.mobile-messaging.notification.key.device-token";
NSString* MMNotificationKeyDLRMessageIDs = @"com.mobile-messaging.notification.key.dlr-message-ids";
NSString* MMNotificationKeyAPIErrorUserInfo = @"com.mobile-messaging.notification.key.api-error";

NSString* MMNotificationKeyMessage = @"com.mobile-messaging.notification.key.message";

NSString* MMNotificationKeyMessagePayload = @"com.mobile-messaging.notification.key.messagePayload";
NSString* MMNotificationKeyMessageCustomPayload = @"com.mobile-messaging.notification.key.message-custom-payload";
NSString* MMNotificationKeyMessageIsPush = @"com.mobile-messaging.notification.key.message-is-push";
NSString* MMNotificationKeyMessageIsSilent = @"com.mobile-messaging.notification.key.message-is-silent";

NSString* MMNotificationKeyMessageSendingMOMessages = @"com.mobile-messaging.notification.key.message-sending-messages";
NSString* MMNotificationKeyGeographicalRegion = @"com.mobile-messaging.notification.key.geographical-region";
NSString* MMNotificationKeyMobileMessagingContext = @"com.mobile-messaging.notification.key.mobile-messaging-context";
