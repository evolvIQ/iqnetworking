//
//  IQStreamingMediaCache.m
//  IQNetworking
//
//  Created by Rickard Petzäll on 2012-12-28.
//  Copyright (c) 2012 EvolvIQ. All rights reserved.
//

#import "IQStreamingMediaCache.h"
#import "IQHTTPServer.h"

@interface IQStreamingMediaCache () {
    IQHTTPServer* server;
}

@end

@interface IQStreamingCachedItem () {
    
}
- (id) initWithURL:(NSURL*)url cache:(IQStreamingMediaCache*)cache;
@end

@implementation IQStreamingMediaCache

static IQStreamingMediaCache* defaultCache = nil;
static NSMutableDictionary* caches = nil;

+ (IQStreamingMediaCache*) defaultCache
{
    if(!defaultCache) defaultCache = [[IQStreamingMediaCache alloc] init];
    return defaultCache;
}

- (id) init
{
    return [self initWithName:@"__default"];
}

- (id) initWithName:(NSString *)name
{
    self = [super init];
    if(self) {
        self->_name = name;
        @synchronized(caches) {
            if([caches objectForKey:name]) {
                [NSException raise:@"CacheAlreadyExists" format:@"The cache %@ is already instantiated", name];
                return nil;
            }
            [caches setObject:[NSValue valueWithNonretainedObject:self] forKey:name];
        }
    }
    return self;
}

- (void) dealloc
{
    @synchronized(caches) {
        [caches removeObjectForKey:_name];
    }
}

- (IQStreamingCachedItem*) cachedItemAtURL:(NSURL*)url
{
    return [[IQStreamingCachedItem alloc] initWithURL:url cache:self];
}
@end

@implementation IQStreamingCachedItem

- (id) initWithURL:(NSURL*)url cache:(IQStreamingMediaCache*)cache
{
    self = [super init];
    if(self) {
        self->_url = url;
        self->_cache = cache;
    }
    return self;
}

@end
