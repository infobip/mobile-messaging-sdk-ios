//
//  MobileMessagingAppDelegate.m
//
//  Created by Andrey K. on 12/04/16.
//
//

#import "MobileMessagingAppDelegateObjc.h"
#import <MobileMessaging/MobileMessaging-Swift.h>

@implementation MobileMessagingAppDelegateObjc

-(BOOL)geofencingServiceEnabled {
	return FALSE;
}

-(NSString *)applicationCode {
	[NSException raise:NSInternalInconsistencyException format:@"Application code not set. Please override `applicationCode` variable in your subclass of `MobileMessagingAppDelegate`."];
    return nil;
}

-(UserNotificationType *)userNotificationType {
	[NSException raise:NSInternalInconsistencyException format:@"UserNotificationType not set. Please override `userNotificationType` variable in your subclass of `MobileMessagingAppDelegate`."];
    return [[UserNotificationType alloc] initWithOptions: @[]];
}

-(BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	MobileMessaging * session = [MobileMessaging withApplicationCode:self.applicationCode notificationType:self.userNotificationType];
	if (self.appGroupId != nil) {
		session = [session withAppGroupId: self.appGroupId];
	}
	[session start: nil];
	return [self mm_application:application didFinishLaunchingWithOptions:launchOptions];
}

-(BOOL)mm_application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	// override this callback in your AppDelegate if needed
	return true;
}

-(void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
	[MobileMessaging didReceiveRemoteNotification:userInfo fetchCompletionHandler:completionHandler];
	[self mm_application:application didReceiveRemoteNotification:userInfo fetchCompletionHandler:completionHandler];
}

-(void)mm_application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
	// override this callback in your AppDelegate if needed
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
-(void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
	[MobileMessaging didReceiveLocalNotification:notification];
	[self mm_application:application didReceiveLocalNotification:notification];
}
#pragma GCC diagnostic pop

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
-(void)mm_application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
	// override this callback in your AppDelegate if needed
}
#pragma GCC diagnostic pop

-(void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
	[MobileMessaging didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
	[self mm_application:application didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
}

-(void)mm_application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
	// override in your AppDelegate if needed
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
-(void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forLocalNotification:(UILocalNotification *)notification completionHandler:(void (^)())completionHandler {
	if (UIDevice.currentDevice.IS_IOS_BEFORE_10) {
		[MobileMessaging handleActionWithIdentifierWithIdentifier:identifier localNotification:notification responseInfo:nil completionHandler:completionHandler];
	}
	[self mm_application:application handleActionWithIdentifier:identifier forLocalNotification:notification withResponseInfo:nil completionHandler:completionHandler];
}
#pragma GCC diagnostic pop

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
-(void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forLocalNotification:(UILocalNotification *)notification withResponseInfo:(NSDictionary *)responseInfo completionHandler:(void (^)())completionHandler {
	if (UIDevice.currentDevice.IS_IOS_BEFORE_10) {
		[MobileMessaging handleActionWithIdentifierWithIdentifier:identifier localNotification:notification responseInfo:responseInfo completionHandler:completionHandler];
	}
    [self mm_application:application handleActionWithIdentifier:identifier forLocalNotification:notification withResponseInfo:responseInfo completionHandler:completionHandler];
}
#pragma GCC diagnostic pop

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
-(void)mm_application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forLocalNotification:(UILocalNotification *)notification withResponseInfo:(NSDictionary *)responseInfo completionHandler:(void (^)(void))completionHandler {
	// override in your AppDelegate if needed
}
#pragma GCC diagnostic pop

-(void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo completionHandler:(void (^)())completionHandler {
	
	if (UIDevice.currentDevice.IS_IOS_BEFORE_10) {
		[MobileMessaging handleActionWithIdentifierWithIdentifier:identifier forRemoteNotification:userInfo responseInfo:nil completionHandler:completionHandler];
	}
	[self mm_application:application handleActionWithIdentifier:identifier forRemoteNotification:userInfo withResponseInfo:nil completionHandler:completionHandler];
}

-(void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo withResponseInfo:(NSDictionary *)responseInfo completionHandler:(void (^)())completionHandler {
	if (UIDevice.currentDevice.IS_IOS_BEFORE_10) {
		[MobileMessaging handleActionWithIdentifierWithIdentifier:identifier forRemoteNotification:userInfo responseInfo:responseInfo completionHandler:completionHandler];
	}
    [self mm_application:application handleActionWithIdentifier:identifier forRemoteNotification:userInfo withResponseInfo:responseInfo completionHandler:completionHandler];
}

-(void)mm_application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo withResponseInfo:(NSDictionary *)responseInfo completionHandler:(void (^)(void))completionHandler {
	// override in your AppDelegate if needed
}

@end
