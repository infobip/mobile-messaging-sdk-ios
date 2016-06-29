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

//MARK: Notification keys
NSString* MMNotificationKeyRegistrationInternalId = @"com.mobile-messaging.notification.key.registration";
NSString* MMNotificationKeyDeviceToken = @"com.mobile-messaging.notification.key.device-token";
NSString* MMNotificationKeyDLRMessageIDs = @"com.mobile-messaging.notification.key.dlr-message-ids";
NSString* MMNotificationKeyAPIErrorUserInfo = @"com.mobile-messaging.notification.key.api-error";
NSString* MMNotificationKeyMessagePayload = @"com.mobile-messaging.notification.key.message";
NSString* MMNotificationKeyMessageAppData = @"com.mobile-messaging.notification.key.message-app-data";
NSString* MMNotificationKeyMessageIsPush = @"com.mobile-messaging.notification.key.message-is-push";
NSString* MMNotificationKeyMessageIsSilent = @"com.mobile-messaging.notification.key.message-is-silent";