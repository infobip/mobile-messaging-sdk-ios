//
//  MobileMessagingAppDelegate.m
//
//  Created by Andrey K. on 12/04/16.
//
//

#import "MobileMessagingAppDelegateObjc.h"
#import <MobileMessaging/MobileMessaging-Swift.h>

@implementation MobileMessagingAppDelegateObjc
-(BOOL)geofencingServiceDisabled {
	return FALSE;
}

-(NSString *)applicationCode {
	[NSException raise:NSInternalInconsistencyException format:@"Application code not set. Please override `applicationCode` variable in your subclass of `MobileMessagingAppDelegate`."];
    return nil;
}

-(UIUserNotificationType)userNotificationType {
	[NSException raise:NSInternalInconsistencyException format:@"UserNotificationType not set. Please override `userNotificationType` variable in your subclass of `MobileMessagingAppDelegate`."];
    return UIUserNotificationTypeNone;
}

-(BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	[[[MobileMessaging withApplicationCode:self.applicationCode notificationType:self.userNotificationType] withGeofencingServiceDisabled:self.geofencingServiceDisabled] start:nil];
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

-(void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo completionHandler:(void (^)())completionHandler {
	[MobileMessaging handleActionWithIdentifier:identifier userInfo:userInfo responseInfo:nil completionHandler:completionHandler];
	[self mm_application:application handleActionWithIdentifier:identifier forRemoteNotification:userInfo completionHandler:completionHandler];
}

-(void)mm_application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo completionHandler:(void (^)())completionHandler {
	// override in your AppDelegate if needed
}

-(void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo withResponseInfo:(NSDictionary *)responseInfo completionHandler:(void (^)())completionHandler {
	[MobileMessaging handleActionWithIdentifier:identifier userInfo:userInfo responseInfo:responseInfo completionHandler:completionHandler];
	[self mm_application:application handleActionWithIdentifier:identifier forRemoteNotification:userInfo withResponseInfo:responseInfo completionHandler:completionHandler];
}

-(void)mm_application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo withResponseInfo:(NSDictionary *)responseInfo completionHandler:(void (^)())completionHandler {
	// override in your AppDelegate if needed
}

@end
