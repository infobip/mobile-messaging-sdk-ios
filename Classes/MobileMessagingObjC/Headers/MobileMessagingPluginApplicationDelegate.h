//
// Created by Goran Tomasic on 10/10/2016.
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
