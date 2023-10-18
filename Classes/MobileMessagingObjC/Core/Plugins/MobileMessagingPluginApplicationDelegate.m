//
// Created by Goran Tomasic on 10/10/2016.
//

#import "MobileMessagingPluginApplicationDelegate.h"

#if __has_include("MobileMessaging-Swift.h")
#import <MobileMessaging-Swift.h>
#else
#import <MobileMessaging/MobileMessaging-Swift.h>
#endif


NSString *ApplicationLaunchedByNotification_Key = @"com.mobile-messaging.application-launched-by-notification";

@interface MobileMessagingPluginApplicationDelegate() {
	id<UIApplicationDelegate> _applicationDelegate;
}
@end

@implementation MobileMessagingPluginApplicationDelegate

+ (instancetype)sharedInstaller {
	static MobileMessagingPluginApplicationDelegate *_sharedInstaller = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_sharedInstaller = [[self alloc] init];
	});
	
	return _sharedInstaller;
}

+ (void)install {
	[[self sharedInstaller] install];
}

- (void)install {
	if (!self.installed){
		_applicationDelegate = [UIApplication sharedApplication].delegate;
		[[UIApplication sharedApplication] setDelegate:self];
		_installed = YES;
	}
}

#pragma mark - Application Delegate Methods

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    if ([MM_MTMessage makeWithPayload:userInfo] != nil) {
        [MobileMessaging didReceiveRemoteNotification:[self extendUserInfoIfNeeded: userInfo] fetchCompletionHandler:completionHandler];
    } else if (_applicationDelegate && [_applicationDelegate respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)]) {
		[_applicationDelegate application:application didReceiveRemoteNotification:userInfo fetchCompletionHandler:completionHandler];
    } else {
        completionHandler(UIBackgroundFetchResultNoData);
    }
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
	[MobileMessaging didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
	if (_applicationDelegate && [_applicationDelegate respondsToSelector:@selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)]) {
		[_applicationDelegate application:application didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
	}
}

- (void)setWindow:(UIWindow *)window {
    _applicationDelegate.window = window;
}

- (UIWindow *)window{
    return _applicationDelegate.window;
}

#pragma mark - forwardInvocation

// These methods are used to forward not implemented method calls to the original Application Delegate

- (void)forwardInvocation:(NSInvocation *)anInvocation {
	NSObject *appDelegateObject = (NSObject *)_applicationDelegate;
	if ([super respondsToSelector:[anInvocation selector]]) {
		[super forwardInvocation:anInvocation];
	} else if (appDelegateObject && [appDelegateObject respondsToSelector:[anInvocation selector]]){
		[anInvocation invokeWithTarget:appDelegateObject];
	}
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    BOOL res = [super respondsToSelector:aSelector] || [_applicationDelegate respondsToSelector: aSelector];
    return res;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
	NSMethodSignature *methodSignature = [super methodSignatureForSelector:aSelector];
	
	if (!methodSignature){
		NSObject *appDelegateObject = (NSObject *)_applicationDelegate;
		methodSignature = [appDelegateObject methodSignatureForSelector:aSelector];
	}
	
	return methodSignature;
}

#pragma mark - Utils

- (NSDictionary *)extendUserInfoIfNeeded:(NSDictionary *)userInfo {
	NSMutableDictionary *result = userInfo.mutableCopy;
	if ([UIApplication sharedApplication].applicationState == UIApplicationStateInactive) {
		[result setValue:@YES forKey:ApplicationLaunchedByNotification_Key];
	}
	return result.copy;
}

@end
