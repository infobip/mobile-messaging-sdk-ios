//
//  MobileMessagingAppDelegate.h
//
//  Created by Andrey K. on 12/04/16.
//
//

#import <UIKit/UIKit.h>
@class UserNotificationType;

@interface MobileMessagingAppDelegateObjc : UIResponder <UIApplicationDelegate>

/**
	Passes your Application Code to the Mobile Messaging SDK. In order to provide your own unique Application Code, you override this variable in your application delegate, that you inherit from `MobileMessagingAppDelegate`.
*/
@property (nonnull, nonatomic, readonly) NSString * applicationCode;

@property (nullable, nonatomic, readonly) NSString * appGroupId;
	
/**
	Preferable notification types that indicating how the app alerts the user when a  push notification arrives. You should override this property in your application delegate, that you inherit from `MobileMessagingAppDelegate`.
	- remark: For now, Mobile Messaging SDK doesn't support badge. You should handle the badge counter by yourself.
*/
@property (nonatomic, readonly) UserNotificationType * _Nonnull userNotificationType;

/**
	This is a substitution for the standard `application(:didFinishLaunchingWithOptions:)`.
	You override this method in your own application delegate in case you have chosen the Application Delegate inheritance way to integrate with Mobile Messaging SDK and you have some work to be done when the launch process is almost done and the app is almost ready to run.
*/
-(BOOL)mm_application:(UIApplication * _Nonnull)application didFinishLaunchingWithOptions:(NSDictionary * _Nullable)launchOptions;

/**
	This is a substitution for the standard `application(:didReceiveRemoteNotification:fetchCompletionHandler:)`.
	You override this method in your own application delegate in case you have chosen the Application Delegate inheritance way to integrate with Mobile Messaging SDK and you have some work to be done when a remote notification arrived that indicates there is data to be fetched.
*/
-(void)mm_application:(UIApplication * _Nonnull)application didReceiveRemoteNotification:(NSDictionary * _Nonnull)userInfo fetchCompletionHandler:(void (^ _Nonnull)(UIBackgroundFetchResult))completionHandler;

/**
	This is a substitution for the standard `application(:didRegisterForRemoteNotificationsWithDeviceToken:)`.
	You override this method in your own application delegate in case you have chosen the Application Delegate inheritance way to integrate with Mobile Messaging SDK and you have some work to be done when the app successfully registered with Apple Push Notification service (APNs).
*/
-(void)mm_application:(UIApplication * _Nonnull)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData * _Nonnull)deviceToken;

/**
	This is a substitution for the standard `application(:didReceiveLocalNotification:)`.
	You override this method in your own application delegate in case you have chosen the Application Delegate inheritance way to integrate with Mobile Messaging SDK and you have some work to be done when the running app receives a local notification.
 */
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
-(void)mm_application:(UIApplication * _Nonnull)application didReceiveLocalNotification:(UILocalNotification * _Nonnull)notification;
#pragma GCC diagnostic pop
/**
	This is a substitution for the `application(:handleActionWithIdentifier:forLocalNotification:completionHandler:)`.
	You override this method in your own application delegate in case you have chosen the Application Delegate inheritance way to integrate with Mobile Messaging SDK and you have some work to be done when the user taps an action button in an alert displayed in response to a local notification.
 */
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
-(void)mm_application:(UIApplication * _Nonnull)application handleActionWithIdentifier:(NSString *_Nullable)identifier forLocalNotification:(UILocalNotification * _Nonnull)notification withResponseInfo:(NSDictionary * _Nullable)responseInfo completionHandler:(void (^_Nullable)(void))completionHandler;
#pragma GCC diagnostic pop

/**
	This is a substitution for the `application(:handleActionWithIdentifier:forRemoteNotification:completionHandler:)`.
	You override this method in your own application delegate in case you have chosen the Application Delegate inheritance way to integrate with Mobile Messaging SDK and you have some work to be done when the user taps an action button in an alert displayed in response to a remote notification.
 */
-(void)mm_application:(UIApplication * _Nonnull)application handleActionWithIdentifier:(NSString *_Nullable)identifier forRemoteNotification:(NSDictionary *_Nullable)userInfo withResponseInfo:(NSDictionary * _Nullable)responseInfo completionHandler:(void (^_Nullable)(void))completionHandler;

@end
