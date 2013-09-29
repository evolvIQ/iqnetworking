//
//  IQReachableStatus.h
//  IQNetworking for iOS and Mac OS X
//
//  Copyright 2012 Rickard Petzäll, EvolvIQ
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
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
