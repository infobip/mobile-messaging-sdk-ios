//
// Created by Goran Tomasic on 10/10/2016.
//

#import <Foundation/Foundation.h>

extern NSString *ApplicationLaunchedByNotification_Key;

@protocol NotificationsCaching <NSObject>
- (void)didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;
- (void)didReceiveLocalNotification:(UILocalNotification *)notification;
@end

@interface MobileMessagingCordovaApplicationDelegate : UIResponder <UIApplicationDelegate>

+ (instancetype)sharedInstaller;
+ (void) install:(id<NotificationsCaching>)delegate;

@property (strong, nonatomic) UIWindow *window;
@property (readonly, nonatomic) BOOL installed;

- (void)forwardInvocation:(NSInvocation *)anInvocation;
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector;

@end
