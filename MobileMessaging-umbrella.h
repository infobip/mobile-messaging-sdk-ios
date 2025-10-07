// 
//  MobileMessaging-umbrella.h
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "MMNotifications.h"
#import "MobileMessagingPluginApplicationDelegate.h"
#import "SwiftTryCatch.h"

FOUNDATION_EXPORT double MobileMessagingVersionNumber;
FOUNDATION_EXPORT const unsigned char MobileMessagingVersionString[];
