//
//  IQStreamingMediaCache.h
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

@class IQStreamingCachedItem;

@interface IQStreamingMediaCache : NSObject
/**
 For normal use, the one and only instance of the cache.
 */
+ (IQStreamingMediaCache*) defaultCache;

/**
 Initializes a cache with a specific name (directory prefix). There should be only one
 cache accessing a specific directory at a given time. There is nothing
 preventing an application from instantiating more than one cache, but there
 is usually no need to.
 */
- (id) initWithName:(NSString*)name;

- (IQStreamingCachedItem*) cachedItemAtURL:(NSURL*)url;

@property (nonatomic, readonly) NSString* name;
@end

@interface IQStreamingCachedItem : NSObject
@property (nonatomic, readonly) NSURL* url;
@property (nonatomic, readonly) IQStreamingMediaCache* cache;
@end
