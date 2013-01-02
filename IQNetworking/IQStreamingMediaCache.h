//
//  IQStreamingMediaCache.h
//  IQNetworking
//
//  Created by Rickard Petzäll on 2012-12-28.
//  Copyright (c) 2012 EvolvIQ. All rights reserved.
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
