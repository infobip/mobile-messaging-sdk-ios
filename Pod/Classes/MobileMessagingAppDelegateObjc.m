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

-(UIUserNotificationType)userNotificationType {
	[NSException raise:NSInternalInconsistencyException format:@"UserNotificationType not set. Please override `userNotificationType` variable in your subclass of `MobileMessagingAppDelegate`."];
    return UIUserNotificationTypeNone;
}

-(BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	MobileMessaging * session = [MobileMessaging withApplicationCode:self.applicationCode notificationType:self.userNotificationType];
	if (self.geofencingServiceEnabled) {
		session = [session withGeofencingService];
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

-(void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
	[MobileMessaging didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
	[self mm_application:application didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
}
-(void)mm_application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
	// override in your AppDelegate if needed
}

@end
