//
//  MobileMessagingAppDelegate.h
//  Pods
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
 Preferable notification types that indicating how the app alerts the user when a  push notification arrives. You should override this variable in your application delegate, that you inherit from `MobileMessagingAppDelegate`.
	- remark: For now, Mobile Messaging SDK doesn't support badge. You should handle the badge counter by yourself.
*/
@property (nonatomic, readonly) UIUserNotificationType userNotificationType;

-(BOOL)mm_application:(UIApplication * _Nonnull)application didFinishLaunchingWithOptions:(NSDictionary * _Nullable)launchOptions;
-(void)mm_application:(UIApplication * _Nonnull)application didReceiveRemoteNotification:(NSDictionary * _Nonnull)userInfo fetchCompletionHandler:(void (^ _Nonnull)(UIBackgroundFetchResult))completionHandler;
-(void)mm_application:(UIApplication * _Nonnull)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData * _Nonnull)deviceToken;
-(void)mm_application:(UIApplication * _Nonnull)application handleActionWithIdentifier:(NSString * _Nullable)identifier forRemoteNotification:(NSDictionary * _Nonnull)userInfo completionHandler:(void (^ _Nonnull)())completionHandler;
-(void)mm_application:(UIApplication * _Nonnull)application handleActionWithIdentifier:(NSString * _Nullable)identifier forRemoteNotification:(NSDictionary * _Nonnull)userInfo withResponseInfo:(NSDictionary *_Nullable)responseInfo completionHandler:(void (^ _Nonnull)())completionHandler;
@end
