//
//  IQProgressAgregator.h
//  IQNetworking
//
//  Created by Rickard Petzäll on 2013-01-22.
//  Copyright (c) 2013 EvolvIQ. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol IQProgressible <NSObject>
@required
- (BOOL) isDone;

@optional
- (long long) totalBytes;
- (long long) bytesDone;
@end

#define kIQProgressAggregatorProgressChanged @"kIQProgressAggregatorProgressChanged"
#define kIQProgressibleProgressChanged @"kIQProgressibleProgressChanged"

@interface IQProgressAgregator : NSObject
+ (IQProgressAgregator*) globalAggregator;

/**
 Posts a kIQProgressibleProgressChangedNotification notification. This notification is picked up
 by all objects listening to the progress of this progressible, as well as the global progress
 aggregator, which always listens to all progressible objects.
 */
+ (void) progressChangedForObject:(id<IQProgressible>)object;

- (void) addProgressible:(id<IQProgressible>)object;

@property (nonatomic) BOOL manageNetworkIndicator;

- (long long) totalBytes;
- (long long) bytesDone;
- (BOOL) working;
@end
