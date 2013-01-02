//
//  IQReachableStatus.h
//  IQNetworking
//
//  Created by Rickard Petzäll on 2012-11-27.
//  Copyright (c) 2012 EvolvIQ. All rights reserved.
//
//  Based on Apple's Reachability sample, but simplified for the most common
//  case of detecting general Cellular/WiFi connectivity.
//

#import <Foundation/Foundation.h>

typedef enum {
    IQNetworkUnreachable = 0,
    IQNetworkWiFi,
    IQNetworkWWAN
} IQReachableType;

#define kIQReachableTypeChangedNotification @"kIQReachableTypeChangedNotification"

@interface IQReachableStatus : NSObject

+ (IQReachableType)currentReachability;
+ (BOOL)connectionRequired;
+ (void)startNotifications;
+ (void)stopNotifications;

/**
 Convenience method to make sure notifications are started and add the observer
 to the notification name kIQReachableTypeChangedNotification.
 */
+ (void)addObserver:(id)observer selector:(SEL)selector;
/**
 Convienience method to remove observer, analogous to calling
 <code>[[NSNotificationCenter defaultCenter] removeObserver:observer]</code>.
 */
+ (void)removeObserver:(id)observer;
@end
