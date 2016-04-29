//
//  MobileMessagingAppDelegate.m
//  Pods
//
//  Created by Andrey K. on 12/04/16.
//
//

#import "MobileMessagingAppDelegateObjc.h"
#import <MobileMessaging/MobileMessaging-Swift.h>

@implementation MobileMessagingAppDelegateObjc
-(NSString *)applicationCode {
	NSAssert(NO, @"Application code not set. Please override `applicationCode` variable in your subclass of `MobileMessagingAppDelegate`.");
    return nil;
}

-(UIUserNotificationType)userNotificationType {
	NSAssert(NO, @"UserNotificationType not set. Please override `userNotificationType` variable in your subclass of `MobileMessagingAppDelegate`.");
    return UIUserNotificationTypeNone;
}

-(BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	[MobileMessaging startWithApplicationCode:self.applicationCode];
	UIUserNotificationSettings * settings = [UIUserNotificationSettings settingsForTypes:self.userNotificationType categories:nil];
	[application registerUserNotificationSettings:settings];
	[application registerForRemoteNotifications];
	return [self mm_application:application didFinishLaunchingWithOptions:launchOptions];
}
-(BOOL)mm_application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	// override in your AppDelegate if needed
	return true;
}

-(void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
	[MobileMessaging didReceiveRemoteNotification:userInfo fetchCompletionHandler:completionHandler];
	[self mm_application:application didReceiveRemoteNotification:userInfo fetchCompletionHandler:completionHandler];
}
-(void)mm_application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
	// override in your AppDelegate if needed
}

-(void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
	[MobileMessaging didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
	[self mm_application:application didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
}
-(void)mm_application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
	// override in your AppDelegate if needed
}

@end
