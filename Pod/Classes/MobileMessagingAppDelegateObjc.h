//
//  MobileMessagingAppDelegate.h
//  Pods
//
//  Created by Andrey K. on 12/04/16.
//
//

#import <UIKit/UIKit.h>

@interface MobileMessagingAppDelegateObjc : UIResponder <UIApplicationDelegate>
@property (nonnull, nonatomic, readonly) NSString * applicationCode;
@property (nonatomic, readonly) UIUserNotificationType userNotificationType;

-(BOOL)mm_application:(UIApplication * _Nonnull)application didFinishLaunchingWithOptions:(NSDictionary * _Nullable)launchOptions;
-(void)mm_application:(UIApplication * _Nonnull)application didReceiveRemoteNotification:(NSDictionary * _Nonnull)userInfo fetchCompletionHandler:(void (^ _Nonnull)(UIBackgroundFetchResult))completionHandler;
-(void)mm_application:(UIApplication * _Nonnull)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData * _Nonnull)deviceToken;
@end
