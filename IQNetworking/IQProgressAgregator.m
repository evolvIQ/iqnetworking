//
//  IQProgressAgregator.m
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

#import "IQProgressAgregator.h"
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

static IQProgressAgregator* globalAggregator = nil;
@interface IQProgressAgregator () {
    NSMapTable* progressObjects;
}
@end
@interface _IQProgressibleReference : NSObject {
@public
    long long totalBytes, bytesDone;
    BOOL done;
    __weak id<IQProgressible> object;
}
- (id) initWithProgressible:(id<IQProgressible>)progressible;
- (void) update;
@end

@implementation IQProgressAgregator

+ (IQProgressAgregator*) globalAggregator
{
    if(!globalAggregator) {
        globalAggregator = [[IQProgressAgregator alloc] init];
    }
    return globalAggregator;
}

+ (void) progressChangedForObject:(id<IQProgressible>)object
{
    if(globalAggregator) {
        [globalAggregator addProgressible:object];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kIQProgressibleProgressChanged object:object];
}

- (void) addProgressible:(id<IQProgressible>)object
{
    if(!progressObjects) {
        progressObjects = [NSMapTable weakToStrongObjectsMapTable];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_receivedProgressUpdate:) name:kIQProgressibleProgressChanged object:nil];
    }
    _IQProgressibleReference* pref = [[_IQProgressibleReference alloc] initWithProgressible:object];
    [progressObjects setObject:pref forKey:object];
    [self _updateProgressible:pref];
}

- (void) _updateProgressible:(_IQProgressibleReference*)pref
{
    [pref update];
    if(pref->done) {
        [progressObjects removeObjectForKey:pref->object];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kIQProgressAggregatorProgressChanged object:self];
#if TARGET_OS_IPHONE
    if(_manageNetworkIndicator) {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:self.working];
    }
#endif
}

- (void) _receivedProgressUpdate:(NSNotification*)notification
{
    _IQProgressibleReference* pref = [progressObjects objectForKey:notification.object];
    if(pref) {
        [self _updateProgressible:pref];
    }
}

- (BOOL) working
{
    return progressObjects.count > 0;
}

- (long long) totalBytes
{
    long long tb = 0;
    for(_IQProgressibleReference* pref in progressObjects) {
        tb += pref->totalBytes;
    }
    return tb;
}

- (long long) bytesDone
{
    long long bd = 0;
    for(_IQProgressibleReference* pref in progressObjects) {
        bd += pref->bytesDone;
    }
    return bd;
}

@end

@implementation _IQProgressibleReference

- (id) initWithProgressible:(id<IQProgressible>)progressible
{
    self = [super init];
    if(self) {
        self->object = progressible;
    }
    return self;
}

- (void) update
{
    done = [object isDone];
    if([object respondsToSelector:@selector(bytesDone)] && [object respondsToSelector:@selector(totalBytes)]) {
        totalBytes = [object totalBytes];
        bytesDone = [object bytesDone];
    }
}

@end