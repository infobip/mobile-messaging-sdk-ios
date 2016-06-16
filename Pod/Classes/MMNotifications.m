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
NSString* MMNotificationKeyRegistrationInternalId = @"com.mobile-messaging.notification.registration-key";
NSString* MMNotificationKeyDeviceToken = @"com.mobile-messaging.notification.device-token-key";
NSString* MMNotificationKeyDLRMessageIDs = @"com.mobile-messaging.notification.dlr-key";
NSString* MMNotificationKeyAPIErrorUserInfo = @"com.mobile-messaging.notification.api-error-key";
NSString* MMNotificationKeyMessagePayload = @"com.mobile-messaging.notification.message-key";
NSString* MMNotificationKeyMessageIsPush = @"com.mobile-messaging.notification.message-is-push-key";
NSString* MMNotificationKeyMessageIsSilent = @"com.mobile-messaging.notification.message-is-silent-key";