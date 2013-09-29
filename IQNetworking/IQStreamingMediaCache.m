//
//  IQStreamingMediaCache.m
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
