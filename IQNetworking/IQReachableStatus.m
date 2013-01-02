//
//  IQReachableStatus.m
//  IQNetworking
//
//  Created by Rickard Petzäll on 2012-11-27.
//  Copyright (c) 2012 EvolvIQ. All rights reserved.
//

#import "IQReachableStatus.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <netinet6/in6.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>
#import <SystemConfiguration/SystemConfiguration.h>

@interface IQReachableStatus () {
    SCNetworkReachabilityRef reachabilityRef;
}
// Private methods
+ (IQReachableStatus*)defaultReachability;
- (id)initWithReachabilityRef:(SCNetworkReachabilityRef)ref;
- (BOOL)_startNotifier;
- (void)_stopNotifier;
- (BOOL)_connectionRequired;
- (IQReachableType)_currentReachability;
@end

static void _IQReachableStatusCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info)
{
    @autoreleasepool {
        // Post a notification to notify the client that the network reachability changed.
        [[NSNotificationCenter defaultCenter] postNotificationName:kIQReachableTypeChangedNotification object:nil];
    }
}

static IQReachableType _IQReachableTypeFromFlags(SCNetworkReachabilityFlags flags)
{
    if ((flags & kSCNetworkReachabilityFlagsReachable) == 0) {
        // if target host is not reachable
        return IQNetworkUnreachable;
    }
    
    IQReachableType retVal = IQNetworkUnreachable;
    if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0) {
        // if target host is reachable and no connection is required
        //  then we'll assume (for now) that your on Wi-Fi
        retVal = IQNetworkWiFi;
    }
    
    
    if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
         (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0)) {
        // ... and the connection is on-demand (or on-traffic) if the
        //     calling application is using the CFSocketStream or higher APIs
        
        if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0) {
            // ... and no [user] intervention is needed
            retVal = IQNetworkWiFi;
        }
    }
    
#if TARGET_OS_IPHONE
    if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN) {
        // ... but WWAN connections are OK if the calling application
        //     is using the CFNetwork (CFSocketStream?) APIs.
        retVal = IQNetworkWWAN;
    }
#endif
    return retVal;
}

static IQReachableStatus* _default = nil;

@implementation IQReachableStatus

#pragma mark - API

+ (IQReachableType)currentReachability
{
    return [[IQReachableStatus defaultReachability] _currentReachability];
}

+ (BOOL)connectionRequired
{
    return [[IQReachableStatus defaultReachability] _connectionRequired];
}

+ (void)startNotifications
{
    [[IQReachableStatus defaultReachability] _startNotifier];
}

+ (void)stopNotifications
{
    if(_default) {
        [_default _startNotifier];
    }
}


+ (void)addObserver:(id)observer selector:(SEL)selector
{
    [[NSNotificationCenter defaultCenter] addObserver:observer selector:selector name:kIQReachableTypeChangedNotification object:nil];
}
+ (void)removeObserver:(id)observer
{
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
}

#pragma mark - Private methods

+ (IQReachableStatus*)defaultReachability
{
    if(_default == nil) {
        struct sockaddr_in hostAddress;
        bzero(&hostAddress, sizeof(hostAddress));
        hostAddress.sin_len = sizeof(hostAddress);
        hostAddress.sin_family = AF_INET;
        SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr*)&hostAddress);
        _default = [[IQReachableStatus alloc] initWithReachabilityRef:reachability];
    }
    return _default;
}

- (id)init
{
    [NSException raise:@"ClassIsSingleton" format:@"IQReachableStatus is a singleton"];
    return nil;
}

- (id)initWithReachabilityRef:(SCNetworkReachabilityRef)ref
{
    self = [super init];
    if(self) {
        reachabilityRef = ref;
    }
    return self;
}

- (BOOL)_startNotifier
{
    BOOL retVal = NO;
    SCNetworkReachabilityContext    context = {0, (__bridge void *)(self), NULL, NULL, NULL};
    if(SCNetworkReachabilitySetCallback(reachabilityRef, _IQReachableStatusCallback, &context))
    {
        if(SCNetworkReachabilityScheduleWithRunLoop(reachabilityRef, CFRunLoopGetMain(), kCFRunLoopDefaultMode))
        {
            retVal = YES;
        }
    }
    return retVal;
}

- (void)_stopNotifier
{
    if(reachabilityRef!= NULL)
    {
        SCNetworkReachabilityUnscheduleFromRunLoop(reachabilityRef, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    }
}

- (void)dealloc
{
    [self _stopNotifier];
    if(reachabilityRef!= NULL)
    {
        CFRelease(reachabilityRef);
    }
}

#pragma mark Network Flag Handling

- (BOOL)_connectionRequired
{
    NSAssert(reachabilityRef != NULL, @"connectionRequired called with NULL reachabilityRef");
    SCNetworkReachabilityFlags flags;
    if (SCNetworkReachabilityGetFlags(reachabilityRef, &flags))
    {
        return (flags & kSCNetworkReachabilityFlagsConnectionRequired);
    }
    return NO;
}

- (IQReachableType)_currentReachability
{
    SCNetworkReachabilityFlags flags;
    if (reachabilityRef && SCNetworkReachabilityGetFlags(reachabilityRef, &flags)) {
        return _IQReachableTypeFromFlags(flags);
    }
    return IQNetworkUnreachable;
}
@end
