// 
//  MobileMessagingPluginApplicationDelegate.h
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

extern NSString *ApplicationLaunchedByNotification_Key;

@interface MobileMessagingPluginApplicationDelegate : UIResponder <UIApplicationDelegate>

+ (instancetype)sharedInstaller;
+ (void) install;

@property (strong, nonatomic) UIWindow *window;
@property (readonly, nonatomic) BOOL installed;

- (void)forwardInvocation:(NSInvocation *)anInvocation;
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector;

@end
