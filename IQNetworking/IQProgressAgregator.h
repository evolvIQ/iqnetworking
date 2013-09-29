//
//  IQProgressAgregator.h
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

#if TARGET_OS_IPHONE
@property (nonatomic) BOOL manageNetworkIndicator;
#endif

- (long long) totalBytes;
- (long long) bytesDone;
- (BOOL) working;
@end
