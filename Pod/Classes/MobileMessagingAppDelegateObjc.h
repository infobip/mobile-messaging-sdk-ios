//
//  MobileMessagingAppDelegate.h
//
//  Created by Andrey K. on 12/04/16.
//
//

#import <UIKit/UIKit.h>

@interface MobileMessagingAppDelegateObjc : UIResponder <UIApplicationDelegate>

/**
	Passes your Application Code to the Mobile Messaging SDK. In order to provide your own unique Application Code, you override this variable in your application delegate, that you inherit from `MobileMessagingAppDelegate`.
*/
@property (nonnull, nonatomic, readonly) NSString * applicationCode;

/**
	Preferable notification types that indicating how the app alerts the user when a  push notification arrives. You should override this property in your application delegate, that you inherit from `MobileMessagingAppDelegate`.
	- remark: For now, Mobile Messaging SDK doesn't support badge. You should handle the badge counter by yourself.
*/
@property (nonatomic, readonly) UIUserNotificationType userNotificationType;

/**
	Defines whether the Geofencing service is enabled. Default value is `FALSE` (The service is enabled by default). If you want to disable the Geofencing service you override this property in your application delegate (the one you inherit from `MobileMessagingAppDelegate`) and return `TRUE`.
*/
@property (nonatomic, readonly) BOOL geofencingServiceDisabled;

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

@end
