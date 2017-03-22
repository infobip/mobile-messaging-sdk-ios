//
// Created by Goran Tomasic on 10/10/2016.
//

#import "MobileMessagingCordovaApplicationDelegate.h"
#import <MobileMessaging/MobileMessaging-Swift.h>

@interface MobileMessagingCordovaApplicationDelegate() {
	id<UIApplicationDelegate> _applicationDelegate;
}
@end

@implementation MobileMessagingCordovaApplicationDelegate

+ (instancetype)sharedInstaller {
	static MobileMessagingCordovaApplicationDelegate *_sharedInstaller = nil;
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
		UIResponder *responder = (UIResponder *) _applicationDelegate;
		self.window = [responder valueForKey:@"window"];
		[[UIApplication sharedApplication] setDelegate:self];
		_installed = YES;
	}
}

#pragma mark - Application Delegate Methods

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
	[MobileMessaging didReceiveRemoteNotification:userInfo fetchCompletionHandler:completionHandler];
	if (_applicationDelegate && [_applicationDelegate respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)]) {
		[_applicationDelegate application:application didReceiveRemoteNotification:userInfo fetchCompletionHandler:completionHandler];
	}
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
	[MobileMessaging didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
	if (_applicationDelegate && [_applicationDelegate respondsToSelector:@selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)]) {
		[_applicationDelegate application:application didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
	}
}

#pragma mark - Unknown method handlers

// These methods likely won't be needed, but are added here so any Obj-C calls that are aimed at the original ApplicationDelegate will be forwarded
- (void)forwardInvocation:(NSInvocation *)anInvocation {
	NSObject *appDelegateObject = (NSObject *)_applicationDelegate;
	if ([super respondsToSelector:[anInvocation selector]]) {
		[super forwardInvocation:anInvocation];
	} else if (appDelegateObject && [appDelegateObject respondsToSelector:[anInvocation selector]]){
		[anInvocation invokeWithTarget:appDelegateObject];
	}
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
	NSMethodSignature *methodSignature = [super methodSignatureForSelector:aSelector];
	
	if (!methodSignature){
		NSObject *appDelegateObject = (NSObject *)_applicationDelegate;
		methodSignature = [appDelegateObject methodSignatureForSelector:aSelector];
	}
	
	return methodSignature;
}

@end
